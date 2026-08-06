#!/usr/bin/env Rscript

# Portable daily market-data pipeline for meinKrypto.info.
# It is based on the supplied R analyses, but removes local Windows paths and
# writes every website artifact to public/charts and public/data.

suppressPackageStartupMessages({
  library(quantmod)
  library(fredr)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(lubridate)
  library(corrplot)
  library(scales)
  library(jsonlite)
  library(zoo)
})

options(
  getSymbols.warning4.0 = FALSE,
  getSymbols.yahoo.warning = FALSE,
  timeout = 180
)

args <- commandArgs(trailingOnly = TRUE)
project_root <- if (length(args) >= 1) normalizePath(args[[1]]) else getwd()
chart_dir <- file.path(project_root, "public", "charts")
data_dir <- file.path(project_root, "public", "data")
cache_dir <- file.path(project_root, "data", "market-cache")
dir.create(chart_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

date_start <- as.Date("2016-01-01")
date_end <- Sys.Date() + 1
run_started_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
fred_api_key <- trimws(Sys.getenv("FRED_API_KEY", unset = ""))

if (nzchar(fred_api_key)) {
  fredr::fredr_set_key(fred_api_key)
} else {
  warning(
    paste(
      "FRED_API_KEY is missing. FRED series will use their last-known-good",
      "cache while all other series continue to update."
    ),
    call. = FALSE
  )
}

`%||%` <- function(value, fallback) {
  if (is.null(value) || length(value) == 0 || is.na(value[[1]])) {
    fallback
  } else {
    value
  }
}

iso_utc <- function(value = Sys.time()) {
  format(value, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

atomic_replace <- function(temp_path, target_path) {
  backup_path <- paste0(target_path, ".bak")
  if (file.exists(backup_path)) unlink(backup_path)

  if (file.exists(target_path) && !file.rename(target_path, backup_path)) {
    stop(sprintf("Could not prepare cache file %s for replacement", target_path))
  }

  if (!file.rename(temp_path, target_path)) {
    if (file.exists(target_path)) unlink(target_path)
    if (file.exists(backup_path)) file.rename(backup_path, target_path)
    stop(sprintf("Could not replace cache file %s", target_path))
  }

  if (file.exists(backup_path)) unlink(backup_path)
  invisible(target_path)
}

atomic_write_csv <- function(frame, path) {
  temp_path <- tempfile(
    pattern = paste0(basename(path), ".new-"),
    tmpdir = dirname(path)
  )
  on.exit(if (file.exists(temp_path)) unlink(temp_path), add = TRUE)
  write.csv(frame, temp_path, row.names = FALSE, fileEncoding = "UTF-8")

  roundtrip <- read.csv(
    temp_path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fileEncoding = "UTF-8"
  )
  if (nrow(roundtrip) != nrow(frame) || !all(names(roundtrip) == names(frame))) {
    stop(sprintf("Cache verification failed for %s", path))
  }

  atomic_replace(temp_path, path)
}

atomic_write_json <- function(value, path) {
  temp_path <- tempfile(
    pattern = paste0(basename(path), ".new-"),
    tmpdir = dirname(path)
  )
  on.exit(if (file.exists(temp_path)) unlink(temp_path), add = TRUE)
  write_json(
    value,
    path = temp_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    na = "null",
    digits = 10
  )
  invisible(fromJSON(temp_path, simplifyVector = FALSE))
  atomic_replace(temp_path, path)
}

read_json_safely <- function(path) {
  candidates <- c(path, paste0(path, ".bak"))
  for (candidate in candidates[file.exists(candidates)]) {
    value <- tryCatch(
      fromJSON(candidate, simplifyVector = FALSE),
      error = function(error) NULL
    )
    if (!is.null(value)) return(value)
  }
  NULL
}

validate_series <- function(frame, config, cached = NULL, require_fresh = TRUE) {
  value_column <- config$value_column
  required_columns <- c("day", value_column)
  if (!is.data.frame(frame) || !all(required_columns %in% names(frame))) {
    return(list(ok = FALSE, reason = "expected columns are missing"))
  }

  clean <- frame[, required_columns, drop = FALSE]
  clean$day <- suppressWarnings(as.Date(clean$day))
  clean[[value_column]] <- suppressWarnings(as.numeric(clean[[value_column]]))
  invalid <- is.na(clean$day) |
    is.na(clean[[value_column]]) |
    !is.finite(clean[[value_column]])
  if (isTRUE(config$positive_values)) {
    invalid <- invalid | clean[[value_column]] <= 0
  }

  invalid_share <- if (nrow(clean) == 0) 1 else mean(invalid)
  clean <- clean[!invalid, , drop = FALSE] |>
    distinct(day, .keep_all = TRUE) |>
    arrange(day)

  if (invalid_share > 0.02) {
    return(list(ok = FALSE, reason = "too many invalid observations"))
  }
  if (nrow(clean) < config$min_rows) {
    return(list(ok = FALSE, reason = "too few usable observations"))
  }
  if (max(clean$day) > Sys.Date() + 1) {
    return(list(ok = FALSE, reason = "latest observation lies in the future"))
  }

  if (require_fresh &&
      max(clean$day) < Sys.Date() - config$max_observation_age_days) {
    return(list(ok = FALSE, reason = "latest observation is implausibly old"))
  }

  if (!is.null(cached) && nrow(cached) >= config$min_rows) {
    minimum_expected_rows <- max(
      config$min_rows,
      floor(nrow(cached) * 0.8)
    )
    if (nrow(clean) < minimum_expected_rows) {
      return(list(ok = FALSE, reason = "download is unexpectedly incomplete"))
    }
    if (max(clean$day) < max(cached$day) - config$allowed_regression_days) {
      return(list(ok = FALSE, reason = "download ends before the cached history"))
    }
  }

  list(ok = TRUE, data = clean)
}

read_cached_series <- function(config, path) {
  candidates <- c(path, paste0(path, ".bak"))
  for (candidate in candidates[file.exists(candidates)]) {
    frame <- tryCatch(
      read.csv(
        candidate,
        stringsAsFactors = FALSE,
        check.names = FALSE,
        fileEncoding = "UTF-8"
      ),
      error = function(error) NULL
    )
    checked <- validate_series(
      frame,
      config,
      cached = NULL,
      require_fresh = FALSE
    )
    if (isTRUE(checked$ok)) {
      return(list(data = checked$data, path = candidate))
    }
  }
  list(data = NULL, path = NULL)
}

merge_series_history <- function(cached, downloaded, value_column) {
  if (is.null(cached)) return(downloaded)

  bind_rows(
    mutate(cached, .source_priority = 0L),
    mutate(downloaded, .source_priority = 1L)
  ) |>
    arrange(day, .source_priority) |>
    group_by(day) |>
    slice_tail(n = 1) |>
    ungroup() |>
    select(day, all_of(value_column)) |>
    arrange(day)
}

fetch_yahoo_raw <- function(symbol, from = date_start, to = date_end) {
  symbol_env <- new.env(parent = emptyenv())
  object_name <- suppressWarnings(
    getSymbols(
      symbol,
      src = "yahoo",
      from = from,
      to = to,
      auto.assign = TRUE,
      env = symbol_env,
      warnings = FALSE
    )
  )
  raw <- get(object_name[[1]], envir = symbol_env)
  data.frame(
    day = as.Date(index(raw)),
    price = as.numeric(Cl(raw)),
    stringsAsFactors = FALSE
  )
}

fetch_fred_raw <- function(symbol, from = date_start) {
  if (!nzchar(fred_api_key)) {
    stop("FRED_API_KEY is missing")
  }

  fredr::fredr(
    series_id = symbol,
    observation_start = as.Date(from),
    observation_end = Sys.Date()
  ) |>
    transmute(
      day = as.Date(date),
      value = as.numeric(value)
    )
}

download_with_retries <- function(
  download_fn,
  label,
  validation_fn = NULL,
  attempts = 3
) {
  retry_delays <- c(0, 5, 15)
  last_error <- NULL

  for (attempt in seq_len(attempts)) {
    delay <- retry_delays[[min(attempt, length(retry_delays))]]
    if (delay > 0) Sys.sleep(delay)

    result <- tryCatch(
      download_fn(),
      error = function(error) {
        last_error <<- conditionMessage(error)
        NULL
      }
    )
    if (!is.null(result)) {
      checked <- if (is.null(validation_fn)) {
        list(ok = TRUE, data = result)
      } else {
        validation_fn(result)
      }
      if (isTRUE(checked$ok)) {
        return(list(data = checked$data, attempts = attempt, error = NULL))
      }
      last_error <- checked$reason
    }
  }

  list(
    data = NULL,
    attempts = attempts,
    error = last_error %||% sprintf("%s returned no data", label)
  )
}

parse_utc_time <- function(value) {
  if (is.null(value) || !nzchar(as.character(value))) return(as.POSIXct(NA))
  as.POSIXct(
    as.character(value),
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
}

fetch_series_with_cache <- function(config) {
  csv_path <- file.path(cache_dir, paste0(config$cache_key, ".csv"))
  metadata_path <- file.path(cache_dir, paste0(config$cache_key, ".meta.json"))
  cached_result <- read_cached_series(config, csv_path)
  cached <- cached_result$data
  metadata <- read_json_safely(metadata_path)

  download_fn <- if (config$provider == "fred") {
    function() fetch_fred_raw(config$source_id)
  } else {
    function() fetch_yahoo_raw(config$source_id)
  }

  attempts <- if (config$provider == "fred" && !nzchar(fred_api_key)) 1 else 3
  downloaded <- download_with_retries(
    download_fn,
    config$label,
    validation_fn = function(frame) {
      validate_series(
        frame,
        config,
        cached = cached,
        require_fresh = TRUE
      )
    },
    attempts = attempts
  )
  checked <- if (is.null(downloaded$data)) {
    list(ok = FALSE, reason = downloaded$error)
  } else {
    list(ok = TRUE, data = downloaded$data)
  }

  if (isTRUE(checked$ok)) {
    merged <- merge_series_history(
      cached,
      checked$data,
      config$value_column
    )
    cache_error <- NULL
    cache_updated <- tryCatch({
      atomic_write_csv(merged, csv_path)
      metadata_value <- list(
        schemaVersion = 1,
        key = config$key,
        label = config$label,
        provider = config$provider,
        sourceId = config$source_id,
        lastSuccessfulFetch = run_started_at,
        latestObservation = as.character(max(merged$day)),
        observations = nrow(merged)
      )
      atomic_write_json(metadata_value, metadata_path)
      TRUE
    }, error = function(error) {
      cache_error <<- conditionMessage(error)
      FALSE
    })

    status <- list(
      key = config$key,
      label = config$label,
      provider = config$provider,
      sourceId = config$source_id,
      state = if (cache_updated) "updated" else "updated_cache_write_failed",
      level = if (cache_updated) "current" else "warning",
      attempts = downloaded$attempts,
      cacheUpdated = cache_updated,
      lastSuccessfulFetch = run_started_at,
      latestObservation = as.character(max(merged$day)),
      observations = nrow(merged),
      cacheAgeDays = 0,
      error = cache_error
    )
    message(sprintf("%-24s updated (%s observations)", config$label, nrow(merged)))
    return(list(data = merged, status = status))
  }

  if (!is.null(cached)) {
    last_success_text <- as.character(
      metadata$lastSuccessfulFetch %||% iso_utc(file.info(cached_result$path)$mtime)
    )
    last_success <- parse_utc_time(last_success_text)
    cache_age_days <- if (is.na(last_success)) {
      NA_real_
    } else {
      max(0, as.numeric(difftime(Sys.time(), last_success, units = "days")))
    }
    level <- if (!is.na(cache_age_days) &&
                 cache_age_days > config$critical_cache_age_days) {
      "critical"
    } else if (!is.na(cache_age_days) &&
               cache_age_days > config$warning_cache_age_days) {
      "warning"
    } else {
      "fallback"
    }

    status <- list(
      key = config$key,
      label = config$label,
      provider = config$provider,
      sourceId = config$source_id,
      state = "cache",
      level = level,
      attempts = downloaded$attempts,
      cacheUpdated = FALSE,
      lastSuccessfulFetch = last_success_text,
      latestObservation = as.character(max(cached$day)),
      observations = nrow(cached),
      cacheAgeDays = cache_age_days,
      error = checked$reason
    )
    warning(
      sprintf("%s: using last-known-good cache (%s)", config$label, checked$reason),
      call. = FALSE
    )
    return(list(data = cached, status = status))
  }

  status <- list(
    key = config$key,
    label = config$label,
    provider = config$provider,
    sourceId = config$source_id,
    state = "unavailable",
    level = "critical",
    attempts = downloaded$attempts,
    cacheUpdated = FALSE,
    lastSuccessfulFetch = NULL,
    latestObservation = NULL,
    observations = 0,
    cacheAgeDays = NULL,
    error = checked$reason
  )
  warning(
    sprintf("%s: unavailable and no valid cache exists (%s)", config$label, checked$reason),
    call. = FALSE
  )
  list(data = NULL, status = status)
}

series_config <- function(
  key,
  label,
  provider,
  source_id,
  value_column,
  cache_key,
  min_rows,
  max_observation_age_days,
  warning_cache_age_days,
  critical_cache_age_days,
  positive_values = FALSE,
  allowed_regression_days = 7
) {
  list(
    key = key,
    label = label,
    provider = provider,
    source_id = source_id,
    value_column = value_column,
    cache_key = cache_key,
    min_rows = min_rows,
    max_observation_age_days = max_observation_age_days,
    warning_cache_age_days = warning_cache_age_days,
    critical_cache_age_days = critical_cache_age_days,
    positive_values = positive_values,
    allowed_regression_days = allowed_regression_days
  )
}

daily_config <- function(key, label, source_id, cache_key, max_age = 7) {
  series_config(
    key = key,
    label = label,
    provider = "yahoo",
    source_id = source_id,
    value_column = "price",
    cache_key = cache_key,
    min_rows = 30,
    max_observation_age_days = max_age,
    warning_cache_age_days = 3,
    critical_cache_age_days = 7,
    positive_values = TRUE
  )
}

market_configs <- list(
  daily_config("BTC", "Bitcoin", "BTC-USD", "yahoo-btc", 3),
  daily_config("ETH", "Ethereum", "ETH-USD", "yahoo-eth", 3),
  daily_config("LTC", "Litecoin", "LTC-USD", "yahoo-ltc", 3),
  daily_config("ADA", "Cardano", "ADA-USD", "yahoo-ada", 3),
  daily_config("S&P 500", "S&P 500", "^GSPC", "yahoo-sp500"),
  daily_config("Dow Jones", "Dow Jones", "^DJI", "yahoo-dow-jones"),
  daily_config("Nasdaq", "Nasdaq", "^IXIC", "yahoo-nasdaq"),
  daily_config("DAX", "DAX", "^GDAXI", "yahoo-dax"),
  daily_config("TecDAX", "TecDAX", "^TECDAX", "yahoo-tecdax"),
  daily_config("STOXX 50", "EURO STOXX 50", "^STOXX50E", "yahoo-stoxx50"),
  daily_config("Euro", "Euro/US-Dollar", "EURUSD=X", "yahoo-eurusd"),
  daily_config("Gold", "Gold", "GC=F", "yahoo-gold"),
  daily_config("Kupfer", "Kupfer", "HG=F", "yahoo-copper"),
  daily_config("Öl (Brent)", "Öl (Brent)", "BZ=F", "yahoo-brent"),
  daily_config("Öl (WTI)", "Öl (WTI)", "CL=F", "yahoo-wti"),
  daily_config("BCOM", "Bloomberg Commodity Index", "^BCOM", "yahoo-bcom"),
  daily_config("S&P GSCI", "S&P GSCI", "^SPGSCI", "yahoo-sp-gsci")
)

macro_configs <- list(
  series_config(
    "EU_INFLATION", "Inflation EU", "fred", "CP0000EZCCM086NEST",
    "value", "fred-eu-inflation", 24, 100, 14, 45
  ),
  series_config(
    "US_INFLATION", "Inflation USA", "fred", "CPIAUCSL",
    "value", "fred-us-inflation", 24, 100, 14, 45
  ),
  series_config(
    "EU_POLICY_RATE", "EZB-Leitzins", "fred", "ECBMRRFR",
    "value", "fred-eu-policy-rate", 5, 45, 14, 45,
    allowed_regression_days = 45
  ),
  series_config(
    "US_POLICY_RATE", "Fed-Zielkorridor", "fred", "DFEDTARU",
    "value", "fred-us-policy-rate", 5, 45, 14, 45,
    allowed_regression_days = 45
  )
)

message("Downloading every data series independently...")
all_configs <- c(market_configs, macro_configs)
all_results <- lapply(all_configs, fetch_series_with_cache)
names(all_results) <- vapply(all_configs, function(config) config$key, character(1))

series <- setNames(
  lapply(market_configs, function(config) all_results[[config$key]]$data),
  vapply(market_configs, function(config) config$key, character(1))
)
macro_series <- setNames(
  lapply(macro_configs, function(config) all_results[[config$key]]$data),
  vapply(macro_configs, function(config) config$key, character(1))
)
series_status <- lapply(all_results, function(result) result$status)

has_series <- function(container, key) {
  is.data.frame(container[[key]]) && nrow(container[[key]]) > 0
}

artifact_errors <- list()
artifact_skips <- list()

safe_generate <- function(label, code) {
  tryCatch(
    force(code),
    error = function(error) {
      artifact_errors[[length(artifact_errors) + 1]] <<- list(
        label = label,
        error = conditionMessage(error)
      )
      warning(sprintf("%s was not regenerated: %s", label, conditionMessage(error)), call. = FALSE)
      NULL
    }
  )
}

skip_artifact <- function(label, missing_keys) {
  artifact_skips[[length(artifact_skips) + 1]] <<- list(
    label = label,
    missingSeries = missing_keys
  )
  warning(
    sprintf("%s kept its previous file; missing series: %s", label, paste(missing_keys, collapse = ", ")),
    call. = FALSE
  )
}

write_update_status <- function() {
  states <- vapply(series_status, function(item) item$state, character(1))
  levels <- vapply(series_status, function(item) item$level, character(1))
  fallback_labels <- vapply(
    series_status[states == "cache"],
    function(item) item$label,
    character(1)
  )
  cache_write_failed_labels <- vapply(
    series_status[states == "updated_cache_write_failed"],
    function(item) item$label,
    character(1)
  )
  critical_labels <- vapply(
    series_status[levels == "critical"],
    function(item) item$label,
    character(1)
  )
  unavailable_labels <- vapply(
    series_status[states == "unavailable"],
    function(item) item$label,
    character(1)
  )

  overall_status <- if (length(unavailable_labels) > 0 ||
                        length(artifact_errors) > 0) {
    "degraded"
  } else if (length(fallback_labels) > 0 ||
             length(cache_write_failed_labels) > 0) {
    "fallback"
  } else {
    "current"
  }
  display_warning <- length(critical_labels) > 0 || length(artifact_errors) > 0
  public_message <- if (length(unavailable_labels) > 0) {
    "Einzelne Datenreihen sind derzeit nicht verfügbar. Betroffene Darstellungen zeigen den letzten veröffentlichten Stand."
  } else if (length(artifact_errors) > 0) {
    "Einzelne Darstellungen konnten nicht neu berechnet werden und zeigen den letzten erfolgreich veröffentlichten Stand."
  } else if (display_warning) {
    "Einzelne Datenreihen konnten länger nicht aktualisiert werden und werden mit dem zuletzt geprüften Stand angezeigt."
  } else {
    NULL
  }

  public_series <- lapply(series_status, function(item) {
    item[c(
      "key", "label", "provider", "state", "level",
      "lastSuccessfulFetch", "latestObservation", "cacheAgeDays"
    )]
  })
  public_status <- list(
    generatedAt = run_started_at,
    overallStatus = overall_status,
    displayWarning = display_warning,
    message = public_message,
    summary = list(
      total = length(series_status),
      updated = sum(states %in% c("updated", "updated_cache_write_failed")),
      cached = sum(states == "cache"),
      unavailable = sum(states == "unavailable"),
      artifactErrors = length(artifact_errors),
      retainedArtifactGroups = length(artifact_skips)
    ),
    series = public_series
  )
  private_status <- public_status
  private_status$series <- series_status
  private_status$artifactErrors <- artifact_errors
  private_status$artifactSkips <- artifact_skips

  atomic_write_json(public_status, file.path(data_dir, "update-status.json"))
  atomic_write_json(private_status, file.path(cache_dir, "latest-run.json"))

  message("Data-series update summary:")
  for (item in series_status) {
    message(sprintf("  %-24s %s", item$label, item$state))
  }
  message(sprintf(
    "Overall: %s (%s updated, %s cached, %s unavailable)",
    overall_status,
    sum(states %in% c("updated", "updated_cache_write_failed")),
    sum(states == "cache"),
    sum(states == "unavailable")
  ))

  if (length(fallback_labels) > 0 && nzchar(Sys.getenv("GITHUB_ACTIONS"))) {
    cat(sprintf(
      "::warning::Last-known-good cache used for: %s\n",
      paste(fallback_labels, collapse = ", ")
    ))
  }
  if (length(unavailable_labels) > 0 && nzchar(Sys.getenv("GITHUB_ACTIONS"))) {
    cat(sprintf(
      "::warning::No current data or cache available for: %s\n",
      paste(unavailable_labels, collapse = ", ")
    ))
  }
  if (length(artifact_errors) > 0 && nzchar(Sys.getenv("GITHUB_ACTIONS"))) {
    cat(sprintf(
      "::warning::Previous chart files retained after %s generation error(s).\n",
      length(artifact_errors)
    ))
  }
}

write_update_status()

crypto_symbols <- c("BTC", "ETH", "ADA", "LTC")
asset_names <- c(
  BTC = "Bitcoin",
  ETH = "Ethereum",
  ADA = "Cardano",
  LTC = "Litecoin"
)
asset_colours <- c(
  BTC = "#111827",
  ETH = "#627087",
  ADA = "#2777B7",
  LTC = "#C59E2D"
)
benchmark_colours <- c(
  Bitcoin = "#111827",
  DAX = "#2F6F9F",
  `S&P 500` = "#7B61A8",
  Gold = "#C9A22E"
)

site_theme <- function(base_size = 15) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.background = element_rect(fill = "white", colour = NA),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#E8E8E4", linewidth = 0.35),
      axis.title = element_text(colour = "#223044"),
      axis.text = element_text(colour = "#455064"),
      plot.title = element_text(
        colour = "#0B1E33",
        face = "bold",
        size = rel(1.45),
        margin = margin(b = 14)
      ),
      plot.subtitle = element_text(
        colour = "#687386",
        size = rel(0.9),
        margin = margin(b = 16)
      ),
      legend.position = "top",
      legend.justification = "right",
      legend.box.just = "right",
      legend.margin = margin(0, 0, 4, 0),
      legend.title = element_blank(),
      legend.text = element_text(colour = "#455064")
    )
}

legend_inside_top_right <- function() {
  theme(
    legend.position = c(0.985, 0.985),
    legend.justification = c("right", "top"),
    legend.direction = "horizontal",
    legend.background = element_rect(
      fill = scales::alpha("white", 0.92),
      colour = NA
    ),
    legend.margin = margin(5, 7, 5, 7),
    legend.box.margin = margin(0),
    legend.spacing.x = grid::unit(7, "pt")
  )
}

atomic_ggsave <- function(target_path, ...) {
  extension <- tools::file_ext(target_path)
  temp_path <- tempfile(
    pattern = paste0(basename(target_path), ".new-"),
    tmpdir = dirname(target_path),
    fileext = if (nzchar(extension)) paste0(".", extension) else ""
  )
  on.exit(if (file.exists(temp_path)) unlink(temp_path), add = TRUE)
  ggsave(filename = temp_path, ...)
  if (!file.exists(temp_path) || file.info(temp_path)$size <= 0) {
    stop(sprintf("Generated chart is empty: %s", target_path))
  }
  atomic_replace(temp_path, target_path)
}

save_ggplot <- function(plot, filename, width, height, dpi = 160) {
  output_path <- file.path(chart_dir, filename)
  atomic_ggsave(
    target_path = output_path,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    units = "in",
    bg = "white"
  )

  if (tolower(tools::file_ext(filename)) != "svg") {
    svg_filename <- sub("\\.[^.]+$", ".svg", filename)
    atomic_ggsave(
      target_path = file.path(chart_dir, svg_filename),
      plot = plot,
      device = grDevices::svg,
      width = width,
      height = height,
      units = "in",
      bg = "white",
      limitsize = FALSE
    )
  }
}

monthly_returns <- function(frame) {
  frame |>
    arrange(day) |>
    mutate(year = year(day), month = month(day)) |>
    group_by(year, month) |>
    summarise(
      monthly_return = (last(price) / first(price) - 1) * 100,
      .groups = "drop"
    ) |>
    filter(year >= 2016) |>
    complete(
      year = seq(2016, year(Sys.Date())),
      month = 1:12
    ) |>
    arrange(year, month)
}

monthly_colour_limit <- 40

plot_monthly_heatmap <- function(frame, title, filename) {
  monthly <- monthly_returns(frame)
  year_levels <- rev(sort(unique(monthly$year)))
  month_labels <- c(
    "Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
    "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"
  )
  monthly <- monthly |>
    mutate(
      year = factor(year, levels = year_levels),
      month = factor(month, levels = 1:12, labels = month_labels)
    )

  plot <- ggplot(monthly, aes(x = month, y = year, fill = monthly_return)) +
    geom_tile(colour = "white", linewidth = 0.7) +
    geom_text(
      aes(
        label = if_else(
          is.na(monthly_return),
          "",
          sprintf("%.1f%%", monthly_return)
        ),
        colour = !is.na(monthly_return) &
          abs(monthly_return) > monthly_colour_limit * 0.72
      ),
      fontface = "bold",
      size = 3.1
    ) +
    scale_colour_manual(values = c("FALSE" = "#111827", "TRUE" = "white"), guide = "none") +
    scale_fill_gradient2(
      low = "#D9584B",
      mid = "#FAFAF7",
      high = "#258A55",
      midpoint = 0,
      limits = c(-monthly_colour_limit, monthly_colour_limit),
      na.value = "#F0EEE7",
      oob = squish
    ) +
    scale_x_discrete(position = "top", drop = FALSE) +
    labs(title = title, x = NULL, y = NULL) +
    theme_minimal(base_size = 15) +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      panel.grid = element_blank(),
      axis.ticks = element_blank(),
      axis.text.x = element_text(colour = "#455064", size = 12),
      axis.text.y = element_text(colour = "#455064", size = 12),
      plot.title = element_text(
        colour = "#0B1E33",
        face = "bold",
        size = 24,
        hjust = 0.5,
        margin = margin(b = 22)
      ),
      legend.position = "none",
      plot.margin = margin(25, 25, 25, 25)
    )

  save_ggplot(plot, filename, width = 10, height = 10)
}

message("Creating monthly-return heatmaps...")
monthly_configs <- list(
  list(
    key = "BTC",
    title = "Monatliche Renditen von Bitcoin",
    filename = "monthly-bitcoin.png"
  ),
  list(
    key = "ETH",
    title = "Monatliche Renditen von Ethereum",
    filename = "monthly-ethereum.png"
  ),
  list(
    key = "ADA",
    title = "Monatliche Renditen von Cardano",
    filename = "monthly-cardano.png"
  ),
  list(
    key = "LTC",
    title = "Monatliche Renditen von Litecoin",
    filename = "monthly-litecoin.png"
  ),
  list(
    key = "DAX",
    title = "Monatliche Renditen des DAX",
    filename = "monthly-dax.png"
  ),
  list(
    key = "S&P 500",
    title = "Monatliche Renditen des S&P 500",
    filename = "monthly-sp500.png"
  ),
  list(
    key = "Gold",
    title = "Monatliche Renditen von Gold",
    filename = "monthly-gold.png"
  )
)

for (config in monthly_configs) {
  if (has_series(series, config$key)) {
    safe_generate(
      config$title,
      plot_monthly_heatmap(
        series[[config$key]],
        config$title,
        config$filename
      )
    )
  } else {
    skip_artifact(config$title, config$key)
  }
}

return_table <- function(frame, column_name) {
  values <- data.frame(
    day = frame$day[-1],
    value = 100 * diff(log(frame$price))
  )
  names(values)[[2]] <- column_name
  values
}

correlation_keys <- c(
  "BTC", "ETH", "LTC", "ADA",
  "S&P 500", "Dow Jones", "Nasdaq", "DAX", "TecDAX", "STOXX 50",
  "Euro", "Gold", "Kupfer", "Öl (Brent)", "Öl (WTI)", "BCOM", "S&P GSCI"
)

save_correlation <- function(data, title, filename) {
  numeric_data <- data |>
    select(-day)
  correlation <- cor(numeric_data, use = "pairwise.complete.obs")

  draw_correlation <- function() {
    par(bg = "white", mar = c(2, 0, 5.5, 0))
    corrplot(
      correlation,
      method = "color",
      type = "lower",
      addCoef.col = "black",
      number.cex = 0.72,
      tl.col = "black",
      tl.srt = 45,
      tl.cex = 1.02,
      cl.cex = 0.9,
      cl.pos = "b",
      col.lim = c(-1, 1),
      diag = TRUE,
      mar = c(0, 0, 5, 0),
      col = colorRampPalette(c("#B2182B", "#F7F7F7", "#1B9E77"))(200)
    )
    title(main = title, col.main = "#0B1E33", cex.main = 1.35, font.main = 2)
  }

  png_filename <- file.path(chart_dir, filename)
  svg_filename <- file.path(
    chart_dir,
    sub("\\.[^.]+$", ".svg", filename)
  )

  write_correlation_file <- function(target_path, format) {
    temp_path <- tempfile(
      pattern = paste0(basename(target_path), ".new-"),
      tmpdir = dirname(target_path),
      fileext = paste0(".", format)
    )
    on.exit(if (file.exists(temp_path)) unlink(temp_path), add = TRUE)
    device_open <- FALSE
    tryCatch({
      if (format == "png") {
        png(
          filename = temp_path,
          width = 2000,
          height = 2000,
          res = 170,
          bg = "white"
        )
      } else {
        svg(
          filename = temp_path,
          width = 12,
          height = 12,
          bg = "white"
        )
      }
      device_open <- TRUE
      draw_correlation()
      dev.off()
      device_open <- FALSE
    }, error = function(error) {
      if (device_open) dev.off()
      stop(error)
    })
    if (!file.exists(temp_path) || file.info(temp_path)$size <= 0) {
      stop(sprintf("Generated chart is empty: %s", target_path))
    }
    atomic_replace(temp_path, target_path)
  }

  write_correlation_file(png_filename, "png")
  write_correlation_file(svg_filename, "svg")
}

message("Creating correlation matrices...")
missing_correlation_series <- correlation_keys[
  !vapply(correlation_keys, function(key) has_series(series, key), logical(1))
]
if (length(missing_correlation_series) == 0) {
  safe_generate("Korrelationsmatrizen", {
    returns <- Reduce(
      function(x, y) inner_join(x, y, by = "day"),
      Map(return_table, series[correlation_keys], correlation_keys)
    )
    current_year <- year(Sys.Date())
    cycle_2018_2022 <- returns |>
      filter(day >= as.Date("2018-01-01"), day <= as.Date("2022-12-31"))
    save_correlation(
      cycle_2018_2022,
      "Korrelationsmatrix für die Jahre 2018–2022 (tägliche Renditen)",
      "correlation-2018-2022.png"
    )

    since_2022 <- returns |>
      filter(day >= as.Date("2022-01-01"))
    save_correlation(
      since_2022,
      sprintf(
        "Korrelationsmatrix für die Jahre 2022–%s (tägliche Renditen)",
        current_year
      ),
      "correlation-since-2022.png"
    )

    current_year_returns <- returns |>
      filter(year(day) == current_year)
    if (nrow(current_year_returns) >= 5) {
      save_correlation(
        current_year_returns,
        sprintf("Korrelationsmatrix für %s (tägliche Renditen)", current_year),
        "correlation-current-year.png"
      )
    }
  })
} else {
  skip_artifact("Korrelationsmatrizen", missing_correlation_series)
}

paired_prices <- function(target_key, target_label) {
  bitcoin <- series$BTC |>
    transmute(day, Bitcoin = price)
  target <- series[[target_key]] |>
    select(day, price)
  names(target)[[2]] <- target_label

  inner_join(bitcoin, target, by = "day") |>
    filter(if_all(-day, ~ !is.na(.x))) |>
    arrange(day)
}

plot_relative_pair <- function(target_key, target_label, filename) {
  paired <- paired_prices(target_key, target_label)
  relative_start <- max(as.Date("2024-01-01"), min(paired$day))
  indexed <- paired |>
    filter(day >= relative_start) |>
    mutate(across(-day, ~ 100 * .x / first(.x))) |>
    pivot_longer(-day, names_to = "asset", values_to = "index")

  plot <- ggplot(indexed, aes(x = day, y = index, colour = asset)) +
    geom_hline(yintercept = 100, colour = "#A9B0BA", linewidth = 0.45) +
    geom_line(linewidth = 0.92) +
    scale_colour_manual(
      values = benchmark_colours[c("Bitcoin", target_label)]
    ) +
    scale_y_continuous(labels = function(x) paste0(round(x), "%")) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(
      title = sprintf("Bitcoin und %s im relativen Vergleich", target_label),
      subtitle = sprintf(
        "Preisindex: %s = 100",
        format(relative_start, "%d.%m.%Y")
      ),
      x = NULL,
      y = "Preisindex"
    ) +
    site_theme(base_size = 13) +
    legend_inside_top_right()

  save_ggplot(plot, filename, width = 9.6, height = 6)
}

plot_daily_pair <- function(target_key, target_label, filename) {
  paired_returns <- paired_prices(target_key, target_label) |>
    filter(day >= date_start) |>
    mutate(across(-day, ~ c(NA, 100 * diff(log(.x))))) |>
    drop_na() |>
    pivot_longer(-day, names_to = "asset", values_to = "return")

  plot <- ggplot(
    paired_returns,
    aes(x = day, y = return, colour = asset)
  ) +
    geom_hline(yintercept = 0, colour = "#A9B0BA", linewidth = 0.4) +
    geom_line(linewidth = 0.24, alpha = 0.78) +
    coord_cartesian(ylim = c(-35, 35)) +
    scale_colour_manual(
      values = benchmark_colours[c("Bitcoin", target_label)]
    ) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    scale_x_date(
      limits = c(date_start, Sys.Date()),
      date_breaks = "2 years",
      date_labels = "%Y"
    ) +
    labs(
      title = sprintf("Tägliche Renditen: Bitcoin und %s", target_label),
      subtitle = "Logarithmische Tagesrenditen; Achse auf ±35 % begrenzt",
      x = NULL,
      y = "Tagesrendite"
    ) +
    site_theme(base_size = 13) +
    legend_inside_top_right()

  save_ggplot(plot, filename, width = 9.6, height = 6)
}

message("Creating Bitcoin benchmark comparisons...")
benchmark_configs <- list(
  list(key = "DAX", label = "DAX", slug = "dax"),
  list(key = "S&P 500", label = "S&P 500", slug = "sp500"),
  list(key = "Gold", label = "Gold", slug = "gold")
)

for (config in benchmark_configs) {
  dependencies <- c("BTC", config$key)
  missing_dependencies <- dependencies[
    !vapply(dependencies, function(key) has_series(series, key), logical(1))
  ]
  if (length(missing_dependencies) == 0) {
    safe_generate(
      sprintf("Bitcoin & %s: relativer Vergleich", config$label),
      plot_relative_pair(
        config$key,
        config$label,
        sprintf("bitcoin-%s-relative.png", config$slug)
      )
    )
    safe_generate(
      sprintf("Bitcoin & %s: tägliche Renditen", config$label),
      plot_daily_pair(
        config$key,
        config$label,
        sprintf("bitcoin-%s-daily-returns.png", config$slug)
      )
    )
  } else {
    skip_artifact(
      sprintf("Bitcoin & %s", config$label),
      missing_dependencies
    )
  }
}

available_crypto_symbols <- crypto_symbols[
  vapply(crypto_symbols, function(key) has_series(series, key), logical(1))
]

crypto_returns <- if (length(available_crypto_symbols) == 0) {
  data.frame(
    day = as.Date(character()),
    symbol = character(),
    daily_return = numeric(),
    volatility30d = numeric()
  )
} else {
  bind_rows(lapply(available_crypto_symbols, function(symbol) {
    frame <- series[[symbol]]
    data.frame(
      day = frame$day[-1],
      symbol = symbol,
      daily_return = diff(log(frame$price))
    )
  })) |>
    group_by(symbol) |>
    arrange(day, .by_group = TRUE) |>
    mutate(
      volatility30d = rollapplyr(
        daily_return,
        width = 30,
        FUN = sd,
        fill = NA
      ) * sqrt(365) * 100
    ) |>
    ungroup()
}

crypto_daily_axis_lower <- -60
crypto_daily_axis_upper <- 90

message("Creating daily crypto-return charts...")
plot_crypto_daily_returns <- function(symbol) {
  plot <- crypto_returns |>
    filter(.data$symbol == .env$symbol, day >= date_start) |>
    ggplot(aes(x = day, y = daily_return * 100)) +
    geom_hline(yintercept = 0, colour = "#A9B0BA", linewidth = 0.4) +
    geom_line(colour = asset_colours[[symbol]], linewidth = 0.25, alpha = 0.8) +
    coord_cartesian(
      ylim = c(crypto_daily_axis_lower, crypto_daily_axis_upper)
    ) +
    scale_y_continuous(
      labels = function(x) paste0(round(x), "%"),
      breaks = seq(crypto_daily_axis_lower, crypto_daily_axis_upper, by = 30)
    ) +
    scale_x_date(
      limits = c(date_start, Sys.Date()),
      date_breaks = "2 years",
      date_labels = "%Y"
    ) +
    labs(
      title = sprintf("Tägliche Renditen von %s", asset_names[[symbol]]),
      subtitle = "Logarithmische Tagesrenditen seit 2016; einheitliche Achse −60 % bis +90 %",
      x = NULL,
      y = "Tagesrendite"
    ) +
    site_theme(base_size = 13)

  save_ggplot(
    plot,
    sprintf("daily-%s.png", tolower(asset_names[[symbol]])),
    width = 9.6,
    height = 6
  )
}

invisible(lapply(available_crypto_symbols, function(symbol) {
  safe_generate(
    sprintf("Tägliche Renditen von %s", asset_names[[symbol]]),
    plot_crypto_daily_returns(symbol)
  )
}))

if (length(available_crypto_symbols) == length(crypto_symbols)) {
  safe_generate("Rollierende Krypto-Volatilität", {
    volatility_plot <- crypto_returns |>
      filter(day >= as.Date("2020-01-01")) |>
      ggplot(aes(x = day, y = volatility30d, colour = symbol)) +
      geom_line(linewidth = 0.82, alpha = 0.92) +
      scale_colour_manual(values = asset_colours, labels = asset_names) +
      scale_y_continuous(labels = function(x) paste0(round(x), "%")) +
      scale_x_date(
        limits = c(as.Date("2020-01-01"), Sys.Date()),
        date_breaks = "1 year",
        date_labels = "%Y"
      ) +
      labs(
        title = "Rollierende 30-Tage-Volatilität",
        subtitle = "Annualisierte Volatilität auf Basis täglicher logarithmischer Renditen",
        x = NULL,
        y = "Volatilität p. a."
      ) +
      site_theme(base_size = 14) +
      legend_inside_top_right() +
      theme(axis.text.x = element_text(angle = 35, hjust = 1))
    save_ggplot(
      volatility_plot,
      "crypto-volatility.png",
      width = 12,
      height = 4.2
    )
  })
} else {
  skip_artifact(
    "Rollierende Krypto-Volatilität",
    setdiff(crypto_symbols, available_crypto_symbols)
  )
}

message("Creating crypto price charts...")
plot_asset_price <- function(symbol) {
  accuracy <- if (symbol == "BTC") {
    1000
  } else if (symbol == "ADA") {
    0.01
  } else {
    1
  }

  plot <- ggplot(series[[symbol]], aes(x = day, y = price)) +
    geom_line(colour = asset_colours[[symbol]], linewidth = 0.78) +
    scale_y_continuous(
      labels = label_dollar(
        accuracy = accuracy,
        big.mark = ".",
        decimal.mark = ","
      )
    ) +
    scale_x_date(
      limits = c(date_start, Sys.Date()),
      date_breaks = "2 years",
      date_labels = "%Y"
    ) +
    labs(
      title = sprintf("%s-Preisentwicklung", asset_names[[symbol]]),
      subtitle = "Historische Schlusskurse in US-Dollar",
      x = NULL,
      y = "Preis in USD"
    ) +
    site_theme(base_size = 14)

  save_ggplot(
    plot,
    sprintf("%s-price.png", tolower(asset_names[[symbol]])),
    width = 9.6,
    height = 6
  )
}

invisible(lapply(available_crypto_symbols, function(symbol) {
  safe_generate(
    sprintf("%s-Preisentwicklung", asset_names[[symbol]]),
    plot_asset_price(symbol)
  )
}))

message("Creating 365-day market-card charts...")
plot_market_card_trend <- function(symbol) {
  frame <- series[[symbol]]
  latest_day <- max(frame$day, na.rm = TRUE)
  trend <- frame |>
    filter(day >= latest_day - 365)
  month_labels_de <- c(
    "Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
    "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"
  )

  plot <- ggplot(trend, aes(x = day, y = price)) +
    geom_area(
      fill = alpha(asset_colours[[symbol]], 0.1),
      colour = NA
    ) +
    geom_line(
      colour = asset_colours[[symbol]],
      linewidth = 0.9,
      lineend = "round"
    ) +
    scale_x_date(
      date_breaks = "1 month",
      labels = function(values) {
        month_labels_de[as.integer(format(values, "%m"))]
      },
      expand = expansion(mult = c(0, 0))
    ) +
    scale_y_continuous(expand = expansion(mult = c(0.08, 0.08))) +
    coord_cartesian(clip = "off") +
    theme_minimal(base_size = 13) +
    theme(
      plot.background = element_rect(fill = "transparent", colour = NA),
      panel.background = element_rect(fill = "transparent", colour = NA),
      panel.grid = element_blank(),
      axis.title = element_blank(),
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.text.x = element_text(
        colour = "#687386",
        size = 11,
        margin = margin(t = 5)
      ),
      plot.margin = margin(5, 2, 3, 2)
    )

  atomic_ggsave(
    target_path = file.path(
      chart_dir,
      sprintf("market-%s-365d.svg", tolower(symbol))
    ),
    plot = plot,
    device = grDevices::svg,
    width = 7.2,
    height = 2.4,
    units = "in",
    bg = "transparent",
    limitsize = FALSE
  )
}

invisible(lapply(available_crypto_symbols, function(symbol) {
  safe_generate(
    sprintf("365-Tage-Kursverlauf von %s", asset_names[[symbol]]),
    plot_market_card_trend(symbol)
  )
}))

if (length(available_crypto_symbols) == length(crypto_symbols)) {
  safe_generate("Relativer Vergleich der Kryptowerte", {
    crypto_prices <- Reduce(
      function(x, y) inner_join(x, y, by = "day"),
      lapply(crypto_symbols, function(symbol) {
        values <- series[[symbol]] |>
          select(day, price)
        names(values)[[2]] <- symbol
        values
      })
    )

    relative_crypto_start <- max(as.Date("2020-01-01"), min(crypto_prices$day))
    crypto_relative <- crypto_prices |>
      filter(day >= relative_crypto_start) |>
      mutate(across(all_of(crypto_symbols), ~ 100 * .x / first(.x))) |>
      pivot_longer(
        all_of(crypto_symbols),
        names_to = "asset",
        values_to = "index"
      )

    crypto_relative_plot <- ggplot(
      crypto_relative,
      aes(x = day, y = index, colour = asset)
    ) +
      geom_hline(yintercept = 100, colour = "#A9B0BA", linewidth = 0.45) +
      geom_line(linewidth = 0.9, alpha = 0.94) +
      scale_colour_manual(values = asset_colours, labels = asset_names) +
      scale_y_continuous(labels = function(x) paste0(round(x), "%")) +
      scale_x_date(
        limits = c(relative_crypto_start, Sys.Date()),
        date_breaks = "1 year",
        date_labels = "%Y"
      ) +
      labs(
        title = "Kryptowerte im relativen Vergleich",
        subtitle = sprintf("Preisindex: %s = 100", format(relative_crypto_start, "%d.%m.%Y")),
        x = NULL,
        y = "Preisindex"
      ) +
      site_theme(base_size = 14) +
      legend_inside_top_right() +
      theme(axis.text.x = element_text(angle = 35, hjust = 1))
    save_ggplot(
      crypto_relative_plot,
      "crypto-relative.png",
      width = 12,
      height = 4.2
    )
  })
} else {
  skip_artifact(
    "Relativer Vergleich der Kryptowerte",
    setdiff(crypto_symbols, available_crypto_symbols)
  )
}

eu_inflation <- if (has_series(macro_series, "EU_INFLATION")) {
  macro_series$EU_INFLATION |>
    mutate(value = 100 * (value / lag(value, 12) - 1)) |>
    drop_na()
} else {
  NULL
}
us_inflation <- if (has_series(macro_series, "US_INFLATION")) {
  macro_series$US_INFLATION |>
    mutate(value = 100 * (value / lag(value, 12) - 1)) |>
    drop_na()
} else {
  NULL
}
eu_policy_rate <- macro_series$EU_POLICY_RATE
us_policy_rate <- macro_series$US_POLICY_RATE

plot_bitcoin_macro <- function(
  macro_frame,
  macro_label,
  title,
  subtitle,
  filename,
  macro_colour,
  macro_limits,
  macro_breaks,
  macro_geometry = c("line", "step")
) {
  macro_geometry <- match.arg(macro_geometry)
  bitcoin_panel <- series$BTC |>
    filter(day >= date_start) |>
    transmute(day, value = price)
  macro_panel <- macro_frame |>
    filter(day >= date_start) |>
    select(day, value)

  bitcoin_axis_step <- 20000
  bitcoin_axis_upper <- max(
    bitcoin_axis_step,
    ceiling(max(bitcoin_panel$value, na.rm = TRUE) / bitcoin_axis_step) *
      bitcoin_axis_step
  )
  macro_span <- diff(macro_limits)
  scale_factor <- bitcoin_axis_upper / macro_span
  macro_panel <- macro_panel |>
    mutate(scaled_value = (value - macro_limits[[1]]) * scale_factor)

  macro_layer <- if (macro_geometry == "step") {
    geom_step(
      data = macro_panel,
      aes(x = day, y = scaled_value, colour = macro_label),
      linewidth = 0.9,
      alpha = 0.94,
      direction = "hv"
    )
  } else {
    geom_line(
      data = macro_panel,
      aes(x = day, y = scaled_value, colour = macro_label),
      linewidth = 0.9,
      alpha = 0.94
    )
  }

  plot <- ggplot() +
    geom_line(
      data = bitcoin_panel,
      aes(x = day, y = value, colour = "Bitcoin (USD)"),
      linewidth = 0.72,
      alpha = 0.94
    ) +
    macro_layer +
    scale_colour_manual(
      values = setNames(
        c("#111827", macro_colour),
        c("Bitcoin (USD)", macro_label)
      ),
      breaks = c("Bitcoin (USD)", macro_label)
    ) +
    scale_y_continuous(
      name = "Bitcoin-Kurs (USD)",
      limits = c(0, bitcoin_axis_upper),
      breaks = seq(0, bitcoin_axis_upper, by = bitcoin_axis_step),
      labels = label_dollar(
        accuracy = 1,
        big.mark = ".",
        decimal.mark = ","
      ),
      expand = expansion(mult = c(0, 0)),
      sec.axis = sec_axis(
        ~ . / scale_factor + macro_limits[[1]],
        name = macro_label,
        breaks = macro_breaks,
        labels = label_number(
          accuracy = 0.1,
          suffix = " %",
          decimal.mark = ","
        )
      )
    ) +
    scale_x_date(
      limits = c(date_start, Sys.Date()),
      date_breaks = "2 years",
      date_labels = "%Y"
    ) +
    labs(
      title = title,
      subtitle = subtitle,
      x = NULL
    ) +
    site_theme(base_size = 13) +
    legend_inside_top_right() +
    theme(
      axis.title.y.left = element_text(colour = "#111827"),
      axis.title.y.right = element_text(colour = macro_colour),
      axis.text.y.right = element_text(colour = macro_colour)
    ) +
    guides(colour = guide_legend(nrow = 1, byrow = TRUE))

  save_ggplot(plot, filename, width = 9.6, height = 6)
}

message("Creating Bitcoin macro charts...")
macro_plot_configs <- list(
  list(
    key = "EU_INFLATION",
    frame = eu_inflation,
    label = "Inflation EU (%)",
    title = "Bitcoin & Inflation EU",
    subtitle = "Harmonisierter Verbraucherpreisindex; Veränderung zum Vorjahr",
    filename = "bitcoin-inflation-eu.png",
    colour = "#2F6F9F",
    limits = c(-2, 15),
    breaks = c(-2, 0, 3, 6, 9, 12, 15),
    geometry = "line"
  ),
  list(
    key = "US_INFLATION",
    frame = us_inflation,
    label = "Inflation USA (%)",
    title = "Bitcoin & Inflation USA",
    subtitle = "US-Verbraucherpreisindex; Veränderung zum Vorjahr",
    filename = "bitcoin-inflation-usa.png",
    colour = "#7B61A8",
    limits = c(-2, 15),
    breaks = c(-2, 0, 3, 6, 9, 12, 15),
    geometry = "line"
  ),
  list(
    key = "EU_POLICY_RATE",
    frame = eu_policy_rate,
    label = "EZB-Leitzins (%)",
    title = "Bitcoin & Leitzins EU",
    subtitle = "Hauptrefinanzierungssatz der Europäischen Zentralbank",
    filename = "bitcoin-rate-eu.png",
    colour = "#2F6F9F",
    limits = c(0, 6),
    breaks = 0:6,
    geometry = "step"
  ),
  list(
    key = "US_POLICY_RATE",
    frame = us_policy_rate,
    label = "Fed-Zielkorridor (%)",
    title = "Bitcoin & Leitzins USA",
    subtitle = "Obergrenze des Zielkorridors der US-Notenbank",
    filename = "bitcoin-rate-usa.png",
    colour = "#7B61A8",
    limits = c(0, 6),
    breaks = 0:6,
    geometry = "step"
  )
)

for (config in macro_plot_configs) {
  missing_dependencies <- c(
    if (!has_series(series, "BTC")) "BTC" else character(),
    if (!is.data.frame(config$frame) || nrow(config$frame) == 0) config$key else character()
  )
  if (length(missing_dependencies) == 0) {
    safe_generate(
      config$title,
      plot_bitcoin_macro(
        config$frame,
        config$label,
        config$title,
        config$subtitle,
        config$filename,
        config$colour,
        macro_limits = config$limits,
        macro_breaks = config$breaks,
        macro_geometry = config$geometry
      )
    )
  } else {
    skip_artifact(config$title, missing_dependencies)
  }
}

if (length(available_crypto_symbols) == length(crypto_symbols)) {
  safe_generate("Marktübersicht", {
    snapshot_assets <- lapply(names(asset_names), function(symbol) {
      frame <- series[[symbol]]
      prices <- frame$price
      daily_returns <- diff(log(prices))
      latest_day <- max(frame$day, na.rm = TRUE)
      year_window <- frame |>
        filter(day >= latest_day - 365)
      list(
        symbol = symbol,
        name = unname(asset_names[[symbol]]),
        price = unname(tail(prices, 1)),
        change24h = unname((tail(prices, 1) / tail(prices, 2)[[1]] - 1) * 100),
        change365d = unname(
          (tail(year_window$price, 1) / first(year_window$price) - 1) * 100
        ),
        volatility30d = unname(
          sd(tail(daily_returns, 30), na.rm = TRUE) * sqrt(365) * 100
        )
      )
    })

    crypto_success_times <- vapply(crypto_symbols, function(symbol) {
      as.character(series_status[[symbol]]$lastSuccessfulFetch %||% "")
    }, character(1))
    parsed_times <- as.POSIXct(
      crypto_success_times,
      format = "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
    snapshot_time <- if (all(!is.na(parsed_times))) {
      iso_utc(min(parsed_times))
    } else {
      run_started_at
    }
    market_snapshot <- list(
      updatedAt = snapshot_time,
      generatedAt = run_started_at,
      currency = "USD",
      assets = snapshot_assets
    )
    atomic_write_json(market_snapshot, file.path(data_dir, "market.json"))
  })
} else {
  skip_artifact(
    "Marktübersicht",
    setdiff(crypto_symbols, available_crypto_symbols)
  )
}

write_update_status()

if (length(artifact_errors) > 0) {
  warning(
    sprintf(
      "Market update completed with %s artifact-generation error(s); previous files were retained.",
      length(artifact_errors)
    ),
    call. = FALSE
  )
} else if (length(artifact_skips) > 0) {
  message(sprintf(
    "Market update completed with %s retained artifact group(s).",
    length(artifact_skips)
  ))
} else {
  message("Market data and charts updated successfully.")
}
