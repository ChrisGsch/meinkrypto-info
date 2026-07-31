#!/usr/bin/env Rscript

# Portable daily market-data pipeline for meinKrypto.info.
# It is based on the supplied R analyses, but removes local Windows paths and
# writes every website artifact to public/charts and public/data.

suppressPackageStartupMessages({
  library(quantmod)
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

if (utils::compareVersion(
  as.character(utils::packageVersion("quantmod")),
  "0.4.29"
) < 0) {
  stop(
    "quantmod >= 0.4.29 is required. Run install.packages('quantmod') and restart R."
  )
}

fred_api_key <- trimws(Sys.getenv("FRED_API_KEY", unset = ""))
if (!nzchar(fred_api_key)) {
  stop(
    paste(
      "FRED_API_KEY is missing.",
      "Create a free FRED API key and store it in ~/.Renviron locally",
      "and as the GitHub Actions repository secret FRED_API_KEY."
    )
  )
}

args <- commandArgs(trailingOnly = TRUE)
project_root <- if (length(args) >= 1) normalizePath(args[[1]]) else getwd()
chart_dir <- file.path(project_root, "public", "charts")
data_dir <- file.path(project_root, "public", "data")
dir.create(chart_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)

date_start <- as.Date("2016-01-01")
date_end <- Sys.Date() + 1

fetch_yahoo <- function(symbol, from = date_start, to = date_end, attempts = 3) {
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    result <- tryCatch({
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
      frame <- data.frame(
        day = as.Date(index(raw)),
        price = as.numeric(Cl(raw)),
        stringsAsFactors = FALSE
      )
      frame |>
        filter(!is.na(day), !is.na(price)) |>
        distinct(day, .keep_all = TRUE) |>
        arrange(day)
    }, error = function(error) {
      last_error <<- error
      NULL
    })
    if (!is.null(result) && nrow(result) > 30) return(result)
    Sys.sleep(attempt * 2)
  }
  stop(
    sprintf(
      "Could not download %s after %s attempts: %s",
      symbol,
      attempts,
      if (is.null(last_error)) "no usable observations returned" else conditionMessage(last_error)
    )
  )
}

fetch_fred <- function(symbol, from = date_start, attempts = 3) {
  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    result <- tryCatch({
      symbol_env <- new.env(parent = emptyenv())
      object_name <- suppressWarnings(
        getSymbols(
          symbol,
          src = "FRED",
          from = from,
          api.key = fred_api_key,
          auto.assign = TRUE,
          env = symbol_env,
          warnings = FALSE
        )
      )
      raw <- get(object_name[[1]], envir = symbol_env)
      data.frame(
        day = as.Date(index(raw)),
        value = as.numeric(raw[, 1]),
        stringsAsFactors = FALSE
      ) |>
        filter(!is.na(day), !is.na(value), day >= from) |>
        distinct(day, .keep_all = TRUE) |>
        arrange(day)
    }, error = function(error) {
      last_error <<- error
      NULL
    })
    if (!is.null(result) && nrow(result) > 5) return(result)
    Sys.sleep(attempt * 2)
  }
  stop(
    sprintf(
      "Could not download FRED series %s after %s attempts: %s",
      symbol,
      attempts,
      if (is.null(last_error)) "no usable observations returned" else conditionMessage(last_error)
    )
  )
}

message("Downloading market series...")
series <- list(
  BTC = fetch_yahoo("BTC-USD"),
  ETH = fetch_yahoo("ETH-USD"),
  LTC = fetch_yahoo("LTC-USD"),
  ADA = fetch_yahoo("ADA-USD"),
  `S&P 500` = fetch_yahoo("^GSPC"),
  `Dow Jones` = fetch_yahoo("^DJI"),
  Nasdaq = fetch_yahoo("^IXIC"),
  DAX = fetch_yahoo("^GDAXI"),
  TecDAX = fetch_yahoo("^TECDAX"),
  `STOXX 50` = fetch_yahoo("^STOXX50E"),
  Euro = fetch_yahoo("EURUSD=X"),
  Gold = fetch_yahoo("GC=F"),
  Kupfer = fetch_yahoo("HG=F"),
  `Öl (Brent)` = fetch_yahoo("BZ=F"),
  `Öl (WTI)` = fetch_yahoo("CL=F"),
  BCOM = fetch_yahoo("^BCOM"),
  `S&P GSCI` = fetch_yahoo("^SPGSCI")
)

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

save_ggplot <- function(plot, filename, width, height, dpi = 160) {
  output_path <- file.path(chart_dir, filename)
  ggsave(
    filename = output_path,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    units = "in",
    bg = "white"
  )

  if (tolower(tools::file_ext(filename)) != "svg") {
    svg_filename <- sub("\\.[^.]+$", ".svg", filename)
    ggsave(
      filename = file.path(chart_dir, svg_filename),
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
  plot_monthly_heatmap(
    series[[config$key]],
    config$title,
    config$filename
  )
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

returns <- Reduce(
  function(x, y) inner_join(x, y, by = "day"),
  Map(return_table, series[correlation_keys], correlation_keys)
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
      cl.lim = c(-1, 1),
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

  png(
    filename = png_filename,
    width = 2000,
    height = 2000,
    res = 170,
    bg = "white"
  )
  draw_correlation()
  dev.off()

  svg(
    filename = svg_filename,
    width = 12,
    height = 12,
    bg = "white"
  )
  draw_correlation()
  dev.off()
}

message("Creating correlation matrices...")
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
  plot_relative_pair(
    config$key,
    config$label,
    sprintf("bitcoin-%s-relative.png", config$slug)
  )
  plot_daily_pair(
    config$key,
    config$label,
    sprintf("bitcoin-%s-daily-returns.png", config$slug)
  )
}

crypto_returns <- bind_rows(lapply(crypto_symbols, function(symbol) {
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

invisible(lapply(crypto_symbols, plot_crypto_daily_returns))

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

invisible(lapply(crypto_symbols, plot_asset_price))

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

  ggsave(
    filename = file.path(
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

invisible(lapply(crypto_symbols, plot_market_card_trend))

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

message("Downloading macroeconomic series...")
eu_inflation <- fetch_fred("CP0000EZCCM086NEST") |>
  mutate(value = 100 * (value / lag(value, 12) - 1)) |>
  drop_na()
us_inflation <- fetch_fred("CPIAUCSL") |>
  mutate(value = 100 * (value / lag(value, 12) - 1)) |>
  drop_na()
eu_policy_rate <- fetch_fred("ECBMRRFR")
us_policy_rate <- fetch_fred("DFEDTARU")

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
plot_bitcoin_macro(
  eu_inflation,
  "Inflation EU (%)",
  "Bitcoin & Inflation EU",
  "Harmonisierter Verbraucherpreisindex; Veränderung zum Vorjahr",
  "bitcoin-inflation-eu.png",
  "#2F6F9F",
  macro_limits = c(-2, 15),
  macro_breaks = c(-2, 0, 3, 6, 9, 12, 15),
  macro_geometry = "line"
)
plot_bitcoin_macro(
  us_inflation,
  "Inflation USA (%)",
  "Bitcoin & Inflation USA",
  "US-Verbraucherpreisindex; Veränderung zum Vorjahr",
  "bitcoin-inflation-usa.png",
  "#7B61A8",
  macro_limits = c(-2, 15),
  macro_breaks = c(-2, 0, 3, 6, 9, 12, 15),
  macro_geometry = "line"
)
plot_bitcoin_macro(
  eu_policy_rate,
  "EZB-Leitzins (%)",
  "Bitcoin & Leitzins EU",
  "Hauptrefinanzierungssatz der Europäischen Zentralbank",
  "bitcoin-rate-eu.png",
  "#2F6F9F",
  macro_limits = c(0, 6),
  macro_breaks = 0:6,
  macro_geometry = "step"
)
plot_bitcoin_macro(
  us_policy_rate,
  "Fed-Zielkorridor (%)",
  "Bitcoin & Leitzins USA",
  "Obergrenze des Zielkorridors der US-Notenbank",
  "bitcoin-rate-usa.png",
  "#7B61A8",
  macro_limits = c(0, 6),
  macro_breaks = 0:6,
  macro_geometry = "step"
)

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
    volatility30d = unname(sd(tail(daily_returns, 30), na.rm = TRUE) * sqrt(365) * 100)
  )
})

market_snapshot <- list(
  updatedAt = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  currency = "USD",
  assets = snapshot_assets
)

write_json(
  market_snapshot,
  path = file.path(data_dir, "market.json"),
  auto_unbox = TRUE,
  pretty = TRUE,
  na = "null",
  digits = 8
)

message("Market data and charts updated successfully.")
