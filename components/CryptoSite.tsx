"use client";

/* eslint-disable @next/next/no-img-element -- shared by Next and static GitHub Pages */

import { useEffect, useState } from "react";

type MarketAsset = {
  symbol: string;
  name: string;
  price: number;
  change24h: number | null;
  change365d: number | null;
  volatility30d: number | null;
};

type MarketData = {
  updatedAt: string;
  currency: string;
  assets: MarketAsset[];
};

type Insight = {
  date: string;
  label: string;
  title: string;
  copy: string;
  source: string;
  href: string;
};

type InsightData = {
  items: Insight[];
};

type Chart = {
  src: string;
  title: string;
  description: string;
  shape?: "square" | "landscape";
  updateLabel?: string;
};

type ChartRow = {
  title: string;
  timeframe: string;
  charts: Chart[];
};

const assetLogos: Record<string, string> = {
  BTC: "library/Logo_Bitcoin_UHD_4096px.png",
  ETH: "library/Logo_Ethereum_UHD_4096px.png",
  ADA: "library/Logo_Cardano_UHD_4096px.png",
  LTC: "library/Logo_Litecoin_UHD_4096px.png",
};

const fallbackMarket: MarketData = {
  updatedAt: "2026-07-29T15:44:59Z",
  currency: "USD",
  assets: [
    {
      symbol: "BTC",
      name: "Bitcoin",
      price: 63962.69140625,
      change24h: 0.14298759,
      change365d: -45.75854303,
      volatility30d: 31.28681793,
    },
    {
      symbol: "ETH",
      name: "Ethereum",
      price: 1891.94995117,
      change24h: -1.45829617,
      change365d: -50.1259397,
      volatility30d: 45.59948278,
    },
    {
      symbol: "ADA",
      name: "Cardano",
      price: 0.1626,
      change24h: 0.62566085,
      change365d: -79.21959858,
      volatility30d: 73.44180226,
    },
    {
      symbol: "LTC",
      name: "Litecoin",
      price: 44.99000168,
      change24h: -2.4808397,
      change365d: -58.54691674,
      volatility30d: 37.77638884,
    },
  ],
};

const assetProfiles = [
  {
    symbol: "BTC",
    name: "Bitcoin",
    type: "Digitaler Wertspeicher",
    copy: "Knappes, dezentrales Netzwerk mit einem festen maximalen Angebot von 21 Millionen Bitcoin.",
  },
  {
    symbol: "ETH",
    name: "Ethereum",
    type: "Programmierbare Infrastruktur",
    copy: "Blockchain-Plattform für Smart Contracts, tokenisierte Vermögenswerte und dezentrale Anwendungen.",
  },
  {
    symbol: "ADA",
    name: "Cardano",
    type: "Proof-of-Stake-Netzwerk",
    copy: "Forschungsorientierte Blockchain mit Fokus auf formale Methoden, Skalierung und Governance.",
  },
  {
    symbol: "LTC",
    name: "Litecoin",
    type: "Zahlungsnetzwerk",
    copy: "Etabliertes Netzwerk für schnelle, kostengünstige Transaktionen mit langer Betriebshistorie.",
  },
];

const chartGroups: Record<string, ChartRow[]> = {
  entwicklung: [
    {
      title: "Kursentwicklung & Volatilität im Vergleich",
      timeframe: "Seit 2020 · Kursindex ab gemeinsamem Startwert 100",
      charts: [
        {
          src: "charts/crypto-relative.svg",
          title: "Bitcoin, Litecoin, Ethereum und Cardano",
          description:
            "Der gemeinsame Index macht die relative Wertentwicklung der vier Kryptowerte direkt vergleichbar.",
          shape: "landscape",
        },
        {
          src: "charts/crypto-volatility.svg",
          title: "Rollierende Volatilität (30 Tage)",
          description:
            "Annualisierte Schwankungsintensität der vier Kryptowerte im direkten Vergleich.",
          shape: "landscape",
        },
      ],
    },
    {
      title: "Kursentwicklung der einzelnen Kryptowerte",
      timeframe: "Seit 2016 · Zeiträume ohne Kursdaten bleiben leer",
      charts: [
        {
          src: "charts/bitcoin-price.svg",
          title: "Bitcoin",
          description: "Historische Schlusskurse in US-Dollar.",
          shape: "landscape",
        },
        {
          src: "charts/litecoin-price.svg",
          title: "Litecoin",
          description: "Historische Schlusskurse in US-Dollar.",
          shape: "landscape",
        },
        {
          src: "charts/ethereum-price.svg",
          title: "Ethereum",
          description: "Historische Schlusskurse in US-Dollar.",
          shape: "landscape",
        },
        {
          src: "charts/cardano-price.svg",
          title: "Cardano",
          description: "Historische Schlusskurse in US-Dollar.",
          shape: "landscape",
        },
      ],
    },
    {
      title: "Monatliche Renditen",
      timeframe:
        "Seit 2016 · einheitliche Farbskala −40 % bis +40 % und mehr · Zeiträume ohne Kursdaten bleiben leer",
      charts: [
        {
          src: "charts/monthly-bitcoin.svg",
          title: "Bitcoin",
          description: "Positive und negative Monatsrenditen im Jahresraster.",
          shape: "square",
        },
        {
          src: "charts/monthly-litecoin.svg",
          title: "Litecoin",
          description: "Positive und negative Monatsrenditen im Jahresraster.",
          shape: "square",
        },
        {
          src: "charts/monthly-ethereum.svg",
          title: "Ethereum",
          description: "Positive und negative Monatsrenditen im Jahresraster.",
          shape: "square",
        },
        {
          src: "charts/monthly-cardano.svg",
          title: "Cardano",
          description: "Positive und negative Monatsrenditen im Jahresraster.",
          shape: "square",
        },
      ],
    },
    {
      title: "Tägliche Renditen",
      timeframe:
        "Seit 2016 · logarithmische Tagesrenditen · einheitliche y-Achse −60 % bis +90 %",
      charts: [
        {
          src: "charts/daily-bitcoin.svg",
          title: "Bitcoin",
          description: "Tägliche Schwankungen rund um die Nulllinie.",
          shape: "landscape",
        },
        {
          src: "charts/daily-litecoin.svg",
          title: "Litecoin",
          description: "Tägliche Schwankungen rund um die Nulllinie.",
          shape: "landscape",
        },
        {
          src: "charts/daily-ethereum.svg",
          title: "Ethereum",
          description: "Tägliche Schwankungen rund um die Nulllinie.",
          shape: "landscape",
        },
        {
          src: "charts/daily-cardano.svg",
          title: "Cardano",
          description: "Tägliche Schwankungen rund um die Nulllinie.",
          shape: "landscape",
        },
      ],
    },
  ],
  vergleich: [
    {
      title: "Relative Kursentwicklung",
      timeframe: "01.01.2024 = 100",
      charts: [
        {
          src: "charts/bitcoin-dax-relative.svg",
          title: "Bitcoin & DAX",
          description: "Relative Entwicklung ab einem gemeinsamen Startwert.",
          shape: "landscape",
        },
        {
          src: "charts/bitcoin-sp500-relative.svg",
          title: "Bitcoin & S&P 500",
          description: "Relative Entwicklung ab einem gemeinsamen Startwert.",
          shape: "landscape",
        },
        {
          src: "charts/bitcoin-gold-relative.svg",
          title: "Bitcoin & Gold",
          description: "Relative Entwicklung ab einem gemeinsamen Startwert.",
          shape: "landscape",
        },
      ],
    },
    {
      title: "Tägliche Renditen im Vergleich",
      timeframe: "Seit 2016 · logarithmische Tagesrenditen",
      charts: [
        {
          src: "charts/bitcoin-dax-daily-returns.svg",
          title: "Bitcoin & DAX",
          description: "Tägliche Renditen beider Anlageklassen.",
          shape: "landscape",
        },
        {
          src: "charts/bitcoin-sp500-daily-returns.svg",
          title: "Bitcoin & S&P 500",
          description: "Tägliche Renditen beider Anlageklassen.",
          shape: "landscape",
        },
        {
          src: "charts/bitcoin-gold-daily-returns.svg",
          title: "Bitcoin & Gold",
          description: "Tägliche Renditen beider Anlageklassen.",
          shape: "landscape",
        },
      ],
    },
    {
      title: "Monatliche Renditen",
      timeframe: "Seit 2016 · einheitliche Farbskala −40 % bis +40 % und mehr",
      charts: [
        {
          src: "charts/monthly-bitcoin.svg",
          title: "Bitcoin",
          description: "Monatsrenditen im Jahresraster.",
          shape: "square",
        },
        {
          src: "charts/monthly-dax.svg",
          title: "DAX",
          description: "Monatsrenditen im Jahresraster.",
          shape: "square",
        },
        {
          src: "charts/monthly-sp500.svg",
          title: "S&P 500",
          description: "Monatsrenditen im Jahresraster.",
          shape: "square",
        },
        {
          src: "charts/monthly-gold.svg",
          title: "Gold",
          description: "Monatsrenditen im Jahresraster.",
          shape: "square",
        },
      ],
    },
  ],
  makro: [
    {
      title: "Bitcoin & Inflation",
      timeframe:
        "Seit 2016 · linke Achse Bitcoin-Kurs · rechte Achse Inflation −2 % bis +15 %",
      charts: [
        {
          src: "charts/bitcoin-inflation-eu.svg",
          title: "Bitcoin & Inflation EU",
          description: "Bitcoin im zeitlichen Kontext der Euro-Inflationsrate.",
          shape: "landscape",
          updateLabel: "Mit neuen Makrodaten aktualisiert",
        },
        {
          src: "charts/bitcoin-inflation-usa.svg",
          title: "Bitcoin & Inflation USA",
          description: "Bitcoin im zeitlichen Kontext der US-Inflationsrate.",
          shape: "landscape",
          updateLabel: "Mit neuen Makrodaten aktualisiert",
        },
      ],
    },
    {
      title: "Bitcoin & Leitzins",
      timeframe:
        "Seit 2016 · linke Achse Bitcoin-Kurs · rechte Achse Leitzins 0 % bis 6 %",
      charts: [
        {
          src: "charts/bitcoin-rate-eu.svg",
          title: "Bitcoin & Leitzins EU",
          description: "Bitcoin und der Hauptrefinanzierungssatz der EZB.",
          shape: "landscape",
          updateLabel: "Mit neuen Makrodaten aktualisiert",
        },
        {
          src: "charts/bitcoin-rate-usa.svg",
          title: "Bitcoin & Leitzins USA",
          description: "Bitcoin und die Obergrenze des Fed-Zielkorridors.",
          shape: "landscape",
          updateLabel: "Mit neuen Makrodaten aktualisiert",
        },
      ],
    },
    {
      title: "Korrelationsmatrizen",
      timeframe: "Tägliche Renditen · unterschiedliche Marktphasen",
      charts: [
        {
          src: "charts/correlation-2018-2022.svg",
          title: "2018–2022",
          description: "Zusammenhänge über den Marktzyklus 2018 bis 2022.",
          shape: "square",
        },
        {
          src: "charts/correlation-since-2022.svg",
          title: "2022–heute",
          description: "Zusammenhänge seit Beginn des Jahres 2022.",
          shape: "square",
        },
        {
          src: "charts/correlation-current-year.svg",
          title: "2026",
          description: "Zusammenhänge im laufenden Kalenderjahr.",
          shape: "square",
        },
      ],
    },
  ],
};

const fallbackInsights: Insight[] = [
  {
    date: "24. Juli 2026",
    label: "Regulierung",
    title: "MiCA prägt den europäischen Krypto-Rahmen",
    copy: "Einheitliche EU-Regeln rücken Transparenz, Zulassung und Aufsicht von Krypto-Dienstleistungen stärker in den Mittelpunkt.",
    source: "ESMA",
    href: "https://www.esma.europa.eu/esmas-activities/digital-finance-and-innovation/markets-crypto-assets-regulation-mica",
  },
  {
    date: "23. Juli 2026",
    label: "Ethereum",
    title: "Der Ethereum-Fahrplan bleibt dicht getaktet",
    copy: "Nach den jüngsten Skalierungsschritten richtet sich der Blick auf Hegotá und weitere Verbesserungen an Effizienz und Resilienz.",
    source: "ethereum.org",
    href: "https://ethereum.org/roadmap/",
  },
  {
    date: "12. Juni 2026",
    label: "Cardano",
    title: "Governance und Interoperabilität im Fokus",
    copy: "Die Cardano Foundation berichtet über LayerZero-Integration, Governance-Werkzeuge und Vorbereitungen für das Van-Rossem-Upgrade.",
    source: "Cardano Foundation",
    href: "https://cardanofoundation.org/blog/june-2026-activities",
  },
  {
    date: "23. Juli 2026",
    label: "Banken & Litecoin",
    title: "Kryptohandel wandert in bestehende Banking-Apps",
    copy: "BancaStato integriert Bitcoin, Ethereum und Litecoin über Sygnum und Avaloq direkt in Web- und Mobile-Banking.",
    source: "Sygnum",
    href: "https://www.sygnum.com/news/bancastato-launches-regulatedcrypto-trading-with-sygnumand-avaloq/",
  },
];

const events = [
  {
    title: "Bitcoin, Krypto & Co.",
    subtitle: "Die Geldanlage der Zukunft?",
    audience: "Alle Kundensegmente",
    format: "Präsenzvortrag mit Livestream",
    strength: "Direkter Austausch & Reichweite",
  },
  {
    title: "Bitcoin & Co. verstehen",
    subtitle: "Mehr als nur ein Spekulationsobjekt?",
    audience: "Alle Kundensegmente",
    format: "Webinar mit Aufzeichnung",
    strength: "Große Reichweite & wenig Aufwand",
  },
  {
    title: "Krypto & Kino",
    subtitle: "Krypto-Wissen trifft Popcorn",
    audience: "Jugendmarkt",
    format: "Impulsvortrag & Film",
    strength: "Jugend-Finanzbildung",
  },
  {
    title: "After-Work-Krypto",
    subtitle: "Krypto nach Feierabend",
    audience: "Young Professionals",
    format: "Workshop vor Ort",
    strength: "Innovatives Dialogformat",
  },
  {
    title: "Krypto als Assetklasse",
    subtitle: "Bitcoin & Co. in der Portfoliooptimierung",
    audience: "Private Banking & Firmenkunden",
    format: "Vertiefende Fachveranstaltung",
    strength: "Krypto als Anlageklasse einordnen",
  },
  {
    title: "Blockchain – mehr als Krypto",
    subtitle: "Technologie in Industrie & Wirtschaft",
    audience: "Firmenkunden & Entscheider",
    format: "Impuls mit Diskussionsrunde",
    strength: "Technologie im Geschäftskontext",
  },
  {
    title: "meinKrypto im Fokus",
    subtitle: "Mehrwert des neuen Angebots verstehen",
    audience: "Mitglieder & Vertreter",
    format: "Keynote oder Fachvortrag",
    strength: "Einführung verständlich begleiten",
  },
  {
    title: "Krypto zum Jahresauftakt",
    subtitle: "Positionierung als Zukunftsthema",
    audience: "Mitarbeitende & Führungskräfte",
    format: "Strategischer Kickoff-Impuls",
    strength: "Mitarbeitende für Krypto begeistern",
  },
];

const chartTabs = [
  { id: "entwicklung", label: "Kursentwicklung" },
  { id: "vergleich", label: "Bitcoin im Vergleich" },
  { id: "makro", label: "Makro" },
];

const formatPrice = (value: number, currency: string) =>
  new Intl.NumberFormat("de-DE", {
    style: "currency",
    currency,
    minimumFractionDigits: value < 1 ? 4 : value < 100 ? 2 : 0,
    maximumFractionDigits: value < 1 ? 4 : value < 100 ? 2 : 0,
  }).format(value);

const formatDate = (value: string) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("de-DE", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Berlin",
  }).format(date);
};

export default function CryptoSite() {
  const [market, setMarket] = useState<MarketData>(fallbackMarket);
  const [insights, setInsights] = useState<Insight[]>(fallbackInsights);
  const [activeChartTab, setActiveChartTab] = useState("entwicklung");
  const [lightbox, setLightbox] = useState<Chart | null>(null);
  const [legalPanel, setLegalPanel] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    let active = true;
    fetch("data/market.json", { cache: "no-store" })
      .then((response) => {
        if (!response.ok) throw new Error("market data unavailable");
        return response.json() as Promise<MarketData>;
      })
      .then((data) => {
        if (active && data.assets?.length) setMarket(data);
      })
      .catch(() => {
        // The checked-in fallback keeps the page useful if a data provider is
        // temporarily unavailable during the scheduled update.
      });

    fetch("data/insights.json", { cache: "no-store" })
      .then((response) => {
        if (!response.ok) throw new Error("insights unavailable");
        return response.json() as Promise<InsightData>;
      })
      .then((data) => {
        if (active && data.items?.length) setInsights(data.items);
      })
      .catch(() => {
        // The checked-in fallback keeps the editorial section visible if the
        // separately editable content file is temporarily unavailable.
      });

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setLightbox(null);
        setLegalPanel(null);
        setMenuOpen(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  const closeMenu = () => setMenuOpen(false);
  const activeChartRows = chartGroups[activeChartTab];
  const chartVersion = market.updatedAt.slice(0, 10);
  const chartSource = (src: string) => `${src}?v=${chartVersion}`;

  return (
    <div className="site-shell">
      <a className="skip-link" href="#inhalt">
        Zum Inhalt springen
      </a>

      <header className="site-header">
        <a className="brand" href="#top" aria-label="meinKrypto.info Startseite">
          <img src="assets/logo.png" alt="" className="brand-mark" />
          <span className="brand-name">
            meinKrypto<span>.info</span>
          </span>
        </a>

        <button
          className="menu-toggle"
          type="button"
          aria-expanded={menuOpen}
          aria-controls="main-navigation"
          aria-label={menuOpen ? "Menü schließen" : "Menü öffnen"}
          onClick={() => setMenuOpen((value) => !value)}
        >
          <span />
          <span />
        </button>

        <nav
          id="main-navigation"
          className={`main-navigation ${menuOpen ? "is-open" : ""}`}
          aria-label="Hauptnavigation"
        >
          <a href="#markt" onClick={closeMenu}>
            Markt
          </a>
          <a href="#analysen" onClick={closeMenu}>
            Analysen
          </a>
          <a href="#einordnung" onClick={closeMenu}>
            Einordnung
          </a>
          <a href="#veranstaltungen" onClick={closeMenu}>
            Veranstaltungen
          </a>
          <a href="#ueber-mich" onClick={closeMenu}>
            Über mich
          </a>
        </nav>

        <a
          className="header-cta"
          href="mailto:meinKrypto@christoph-gschnaidtner.de?subject=Anfrage%20über%20meinKrypto.info"
        >
          Veranstaltung anfragen
        </a>
      </header>

      <main id="inhalt">
        <section className="hero" id="top">
          <div className="hero-glow hero-glow-one" />
          <div className="hero-glow hero-glow-two" />
          <div className="hero-grid" />

          <div className="hero-content">
            <p className="eyebrow">
              Kryptowerte verstehen. Entwicklungen einordnen.
            </p>
            <h1>
              Krypto, <em>klarer</em> betrachtet.
            </h1>
            <p className="hero-copy">
              Fundierte Einordnungen zu Bitcoin, Ethereum, Cardano und
              Litecoin – verbunden mit Daten, Vergleichen und
              Veranstaltungsformaten für Banken und ihre Kundinnen und Kunden.
            </p>
            <div className="hero-actions">
              <a className="button button-outline-gold" href="#markt">
                Marktdaten ansehen
              </a>
              <a className="button button-secondary" href="#veranstaltungen">
                Veranstaltungsformate
              </a>
            </div>
            <div className="hero-proof">
              <div>
                <strong>4</strong>
                <span>meinKrypto-Werte</span>
              </div>
              <div>
                <strong>Täglich</strong>
                <span>aktualisierte Analysen</span>
              </div>
              <div>
                <strong>Seit 2015</strong>
                <span>Referent für Krypto & Blockchain</span>
              </div>
            </div>
          </div>

          <aside className="market-pulse" aria-label="Aktueller Marktüberblick">
            <div className="pulse-header">
              <div>
                <span className="live-dot" />
                Marktüberblick
              </div>
              <span>USD</span>
            </div>
            <div className="pulse-list">
              {market.assets.map((asset) => (
                <div className="pulse-row" key={asset.symbol}>
                  <div className={`coin coin-${asset.symbol.toLowerCase()}`}>
                    <img src={assetLogos[asset.symbol]} alt="" />
                  </div>
                  <div className="pulse-asset">
                    <strong>{asset.name}</strong>
                    <span>{asset.symbol}</span>
                  </div>
                  <div className="pulse-price">
                    <strong>{formatPrice(asset.price, market.currency)}</strong>
                    <span
                      className={
                        asset.change24h === null
                          ? ""
                          : asset.change24h >= 0
                            ? "positive"
                            : "negative"
                      }
                    >
                      {asset.change24h === null
                        ? "24 h: –"
                        : `${asset.change24h >= 0 ? "+" : ""}${asset.change24h.toFixed(2)} %`}
                    </span>
                  </div>
                </div>
              ))}
            </div>
            <div className="pulse-footer">
              <span>Datenstand</span>
              <time dateTime={market.updatedAt}>
                {formatDate(market.updatedAt)} Uhr
              </time>
            </div>
          </aside>

          <div className="hero-scroll" aria-hidden="true">
            <span />
            Scrollen
          </div>
        </section>

        <section className="section market-section" id="markt">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Markt verstehen</p>
              <h2>Vier Kryptowerte. Vier unterschiedliche Profile.</h2>
            </div>
            <p>
              Ein gemeinsames Marktsegment bedeutet nicht, dass Technologie,
              Nutzen und Risikotreiber identisch sind.
            </p>
          </div>

          <div className="asset-grid">
            {assetProfiles.map((profile) => {
              const liveAsset = market.assets.find(
                (asset) => asset.symbol === profile.symbol,
              );
              return (
                <article className="asset-card" key={profile.symbol}>
                  <div className="asset-card-top">
                    <img
                      className="asset-logo"
                      src={assetLogos[profile.symbol]}
                      alt={`${profile.name}-Logo`}
                      loading="lazy"
                    />
                    <span className="asset-type">{profile.type}</span>
                  </div>
                  <h3>
                    {profile.name}{" "}
                    <span className="asset-code">({profile.symbol})</span>
                  </h3>
                  <p>{profile.copy}</p>
                  <div className="asset-trend">
                    <div className="asset-trend-heading">
                      <span>Kursentwicklung · 365 Tage</span>
                      {liveAsset?.change365d != null && (
                        <strong
                          className={
                            liveAsset.change365d >= 0
                              ? "positive"
                              : "negative"
                          }
                        >
                          {`${liveAsset.change365d >= 0 ? "+" : ""}${liveAsset.change365d.toFixed(1)} %`}
                        </strong>
                      )}
                    </div>
                    <img
                      src={chartSource(
                        `charts/market-${profile.symbol.toLowerCase()}-365d.svg`,
                      )}
                      alt={`Kursentwicklung von ${profile.name} in den vergangenen 365 Tagen`}
                      loading="lazy"
                    />
                  </div>
                  <div className="asset-metrics">
                    <div>
                      <span>Marktpreis</span>
                      <strong>
                        {liveAsset
                          ? formatPrice(liveAsset.price, market.currency)
                          : "–"}
                      </strong>
                    </div>
                    <div>
                      <span>30-Tage-Volatilität</span>
                      <strong>
                        {liveAsset?.volatility30d == null
                          ? "wird berechnet"
                          : `${liveAsset.volatility30d.toFixed(1)} %`}
                      </strong>
                    </div>
                  </div>
                </article>
              );
            })}
          </div>
          <p className="data-note">
            Kurse in USD. Verzögerte Schlusskursdaten; keine Echtzeitkurse und
            keine Anlageberatung.
          </p>
        </section>

        <section className="section analysis-section" id="analysen">
          <div className="section-heading section-heading-light">
            <div>
              <p className="eyebrow">Datenbasierte Perspektive</p>
              <h2>Zusammenhänge statt Momentaufnahmen.</h2>
            </div>
            <p>
              Die Auswertungen werden automatisch aus Marktdaten neu berechnet
              und täglich veröffentlicht.
            </p>
          </div>

          <div className="chart-tabs" role="tablist" aria-label="Analysekategorien">
            {chartTabs.map((tab) => (
              <button
                key={tab.id}
                id={`chart-tab-${tab.id}`}
                type="button"
                role="tab"
                aria-selected={activeChartTab === tab.id}
                aria-controls={`chart-panel-${tab.id}`}
                className={activeChartTab === tab.id ? "is-active" : ""}
                onClick={() => setActiveChartTab(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div
            className="chart-rows"
            id={`chart-panel-${activeChartTab}`}
            role="tabpanel"
            aria-labelledby={`chart-tab-${activeChartTab}`}
          >
            {activeChartRows.map((row) => (
              <section className="chart-row-group" key={row.title}>
                <div className="chart-row-heading">
                  <h3>{row.title}</h3>
                  <p>{row.timeframe}</p>
                </div>
                <div
                  className={`chart-row chart-row-${Math.min(row.charts.length, 4)}`}
                >
                  {row.charts.map((chart) => (
                    <article
                      className={[
                        "chart-card",
                        chart.shape === "landscape"
                          ? "chart-card-landscape"
                          : "chart-card-square",
                      ]
                        .filter(Boolean)
                        .join(" ")}
                      key={chart.src}
                    >
                      <button
                        className="chart-image-button"
                        type="button"
                        onClick={() => setLightbox(chart)}
                        aria-label={`${chart.title} vergrößern`}
                      >
                        <img
                          src={chartSource(chart.src)}
                          alt={chart.title}
                          loading="lazy"
                        />
                        <span className="expand-label">Vergrößern ↗</span>
                      </button>
                      <div className="chart-card-copy">
                        <p className="chart-kicker">
                          {chart.updateLabel ?? "Täglich aktualisiert"}
                        </p>
                        <h3>{chart.title}</h3>
                        <p>{chart.description}</p>
                      </div>
                    </article>
                  ))}
                </div>
              </section>
            ))}
          </div>
        </section>

        <section className="section insights-section" id="einordnung">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Aktuelle Einordnung</p>
              <h2>Was den Kryptomarkt gerade bewegt.</h2>
            </div>
            <p>
              Kuratierte Entwicklungen aus Regulierung, Technologie und
              Bankeninfrastruktur – kompakt und quellenbasiert.
            </p>
          </div>

          <div className="insight-grid">
            {insights.map((insight, index) => (
              <article className="insight-card" key={insight.title}>
                <div className="insight-number">
                  {String(index + 1).padStart(2, "0")}
                </div>
                <div className="insight-meta">
                  <span>{insight.label}</span>
                  <time>{insight.date}</time>
                </div>
                <h3>{insight.title}</h3>
                <p>{insight.copy}</p>
                <a href={insight.href} target="_blank" rel="noreferrer">
                  Quelle: {insight.source} <span aria-hidden="true">↗</span>
                </a>
              </article>
            ))}
          </div>
        </section>

        <section className="section event-section" id="veranstaltungen">
          <div className="event-intro">
            <div>
              <p className="eyebrow">Kundenveranstaltungen rund um meinKrypto</p>
              <h2>Information, Orientierung und echter Dialog.</h2>
            </div>
            <div>
              <p>
                Passende Formate für Kundinnen und Kunden, Mitglieder,
                Mitarbeitende, Private Banking, Firmenkunden und den
                Jugendmarkt.
              </p>
              <a
                className="button button-primary event-download-button"
                href="library/Website/2026_Übersicht_Kundenveranstaltungen_Krypto_Gschnaidtner.pdf"
                download="2026_Übersicht_Kundenveranstaltungen_Krypto_Gschnaidtner.pdf"
              >
                Veranstaltungsübersicht als PDF
                <span aria-hidden="true">↓</span>
              </a>
            </div>
          </div>

          <div className="event-grid">
            {events.map((event) => (
              <article className="event-card" key={event.title}>
                <p className="event-audience">{event.audience}</p>
                <h3 className={event.title.length > 24 ? "event-title-long" : ""}>
                  {event.title}
                </h3>
                <p className="event-subtitle">{event.subtitle}</p>
                <dl>
                  <div>
                    <dt>Format</dt>
                    <dd>{event.format}</dd>
                  </div>
                  <div>
                    <dt>Stärke</dt>
                    <dd>{event.strength}</dd>
                  </div>
                </dl>
                <a
                  href={`mailto:meinKrypto@christoph-gschnaidtner.de?subject=${encodeURIComponent(`Anfrage: ${event.title}`)}`}
                >
                  Format anfragen <span aria-hidden="true">→</span>
                </a>
              </article>
            ))}
          </div>
        </section>

        <section className="contact-section" id="ueber-mich">
          <div className="contact-decoration" />
          <div className="contact-copy">
            <p className="eyebrow">Über mich</p>
            <h2>Wissenschaftlich fundiert. Verständlich vermittelt.</h2>
            <p>
              Ich bin Christoph Gschnaidtner und beschäftige mich seit mehr als
              zehn Jahren mit Kryptowerten, Blockchain und Finanzmärkten. Seit
              2015 vermittle ich diese Themen als Dozent und Referent – mit
              besonderem Blick auf Banken, Finanzdienstleister und deren
              Kundinnen und Kunden.
            </p>
            <p>
              Meine Vorträge verbinden Financial Economics, Finanzmathematik
              und quantitative Methoden mit Erfahrung aus Forschung, Lehre und
              Beratung. Der Fokus meiner Forschung liegt ebenfalls auf Geld und
              Währungen der Zukunft, d.h. auf Kryptowerten und dem digitalen
              Euro.
            </p>
            <div className="contact-facts">
              <span>Dozent für Krypto & Blockchain seit 2015</span>
              <span>M.Sc. Finance & Information Management</span>
              <span>M.Sc. Finanzmathematik</span>
            </div>
          </div>

          <div className="contact-card">
            <div className="profile-photo-frame">
              <img
                className="profile-photo"
                src="assets/christoph-gschnaidtner.jpg"
                alt="Porträt von Christoph Gschnaidtner"
                loading="lazy"
              />
            </div>
            <div className="contact-card-body">
              <p>Christoph Gschnaidtner</p>
              <h3>Lassen Sie uns über das passende Format sprechen.</h3>
              <a
                className="button button-primary"
                href="mailto:meinKrypto@christoph-gschnaidtner.de?subject=Anfrage%20über%20meinKrypto.info"
              >
                E-Mail schreiben <span aria-hidden="true">↗</span>
              </a>
              <a
                className="contact-detail"
                href="mailto:meinKrypto@christoph-gschnaidtner.de"
              >
                meinKrypto@christoph-gschnaidtner.de
              </a>
            </div>
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="footer-main">
          <a className="brand" href="#top">
            <img src="assets/logo.png" alt="" className="brand-mark" />
            <span className="brand-name">
              meinKrypto<span>.info</span>
            </span>
          </a>
          <p>
            Fundierte Informationen zu Kryptowerten und
            Veranstaltungsangeboten für Banken.
          </p>
        </div>
        <div className="footer-links">
          <button type="button" onClick={() => setLegalPanel("risiko")}>
            Risikohinweis
          </button>
          <button type="button" onClick={() => setLegalPanel("datenschutz")}>
            Datenschutz
          </button>
          <button type="button" onClick={() => setLegalPanel("impressum")}>
            Impressum
          </button>
        </div>
        <div className="footer-bottom">
          <span>© 2026 Christoph Gschnaidtner</span>
          <span>Informationen, keine Anlageberatung.</span>
        </div>
      </footer>

      {lightbox && (
        <div
          className="modal-backdrop chart-lightbox"
          role="dialog"
          aria-modal="true"
          aria-label={lightbox.title}
          onClick={() => setLightbox(null)}
        >
          <div className="lightbox-panel" onClick={(event) => event.stopPropagation()}>
            <button
              className="modal-close"
              type="button"
              onClick={() => setLightbox(null)}
              aria-label="Ansicht schließen"
            >
              ×
            </button>
            <img src={chartSource(lightbox.src)} alt={lightbox.title} />
            <div>
              <h2>{lightbox.title}</h2>
              <p>{lightbox.description}</p>
            </div>
          </div>
        </div>
      )}

      {legalPanel && (
        <div
          className="modal-backdrop"
          role="dialog"
          aria-modal="true"
          aria-label={legalPanel}
          onClick={() => setLegalPanel(null)}
        >
          <div className="legal-panel" onClick={(event) => event.stopPropagation()}>
            <button
              className="modal-close"
              type="button"
              onClick={() => setLegalPanel(null)}
              aria-label="Hinweis schließen"
            >
              ×
            </button>

            {legalPanel === "risiko" && (
              <>
                <p className="eyebrow">Risikohinweis</p>
                <h2>Informationen, keine Anlageberatung.</h2>
                <h3>Allgemeiner Hinweis</h3>
                <p>
                  Die Inhalte dieser Website dienen ausschließlich der
                  allgemeinen Information und Weiterbildung. Sie stellen weder
                  eine Anlage-, Rechts- oder Steuerberatung noch ein Angebot
                  oder eine Aufforderung zum Kauf, Verkauf oder Halten von
                  Kryptowerten oder sonstigen Finanzinstrumenten dar.
                </p>
                <h3>Besondere Risiken von Kryptowerten</h3>
                <p>
                  Kryptowerte können sehr starken Kursschwankungen unterliegen.
                  Ein erheblicher oder vollständiger Verlust des eingesetzten
                  Kapitals ist möglich. Zu den Risiken zählen insbesondere:
                </p>
                <ul>
                  <li>Markt-, Liquiditäts- und Wechselkursrisiken,</li>
                  <li>
                    technische Fehler, Cyberangriffe sowie der Verlust von
                    privaten Schlüsseln oder Zugangsdaten,
                  </li>
                  <li>
                    Änderungen von Protokollen, Regulierung und steuerlicher
                    Behandlung sowie
                  </li>
                  <li>
                    eine je nach Kryptowert und Anbieter nur eingeschränkte
                    gesetzliche oder verbraucherrechtliche Absicherung.
                  </li>
                </ul>
                <p>
                  Kryptowerte sind regelmäßig nicht durch die gesetzliche
                  Einlagensicherung oder Anlegerentschädigung geschützt. Auch
                  die europäische MiCA-Regulierung beseitigt die
                  wirtschaftlichen Risiken einer Anlage nicht. Hinweise zu
                  Risiken und Schutzumfang bietet die{" "}
                  <a
                    href="https://www.esma.europa.eu/press-news/esma-news/eu-supervisory-authorities-warn-consumers-risks-and-limited-protection-certain"
                    target="_blank"
                    rel="noreferrer"
                  >
                    gemeinsame Verbraucherwarnung der europäischen
                    Aufsichtsbehörden
                  </a>
                  .
                </p>
                <h3>Daten und Wertentwicklungen</h3>
                <p>
                  Kurse, Kennzahlen und Diagramme können zeitverzögert,
                  unvollständig oder fehlerhaft sein. Trotz sorgfältiger
                  Aufbereitung wird keine Gewähr für Richtigkeit,
                  Vollständigkeit, Aktualität oder dauerhafte Verfügbarkeit
                  übernommen. Historische Wertentwicklungen und statistische
                  Zusammenhänge sind kein verlässlicher Indikator für
                  zukünftige Ergebnisse.
                </p>
                <p>
                  Anlageentscheidungen erfolgen in eigener Verantwortung und
                  sollten die persönliche finanzielle Situation,
                  Risikotragfähigkeit und gegebenenfalls unabhängige
                  fachkundige Beratung berücksichtigen. Zwingende gesetzliche
                  Haftungsregelungen bleiben unberührt.
                </p>
              </>
            )}

            {legalPanel === "datenschutz" && (
              <>
                <p className="eyebrow">Datenschutz</p>
                <h2>Datenschutzhinweise</h2>
                <h3>1. Verantwortlicher</h3>
                <address>
                  Christoph Gschnaidtner
                  <br />
                  Am Steinberg 40
                  <br />
                  82237 Wörthsee
                  <br />
                  Deutschland
                  <br />
                  E-Mail:{" "}
                  <a href="mailto:meinKrypto@christoph-gschnaidtner.de">
                    meinKrypto@christoph-gschnaidtner.de
                  </a>
                </address>

                <h3>2. Aufruf der Website und Hosting</h3>
                <p>
                  Die öffentliche Website unter meinKrypto.info wird als
                  statische Website über GitHub Pages bereitgestellt. Anbieter
                  sind GitHub B.V., Prins Bernhardplein 200, 1097 JB Amsterdam,
                  Niederlande, und GitHub, Inc., 88 Colin P. Kelly Jr. Street,
                  San Francisco, CA 94107, USA.
                </p>
                <p>
                  Beim Abruf der Website werden technisch erforderliche
                  Verbindungsdaten verarbeitet. Dazu können insbesondere
                  IP-Adresse, Datum und Uhrzeit, aufgerufene Datei, übertragene
                  Datenmenge, Referrer-URL, Browser und Betriebssystem gehören.
                  GitHub protokolliert beim Besuch einer GitHub-Pages-Website
                  die IP-Adresse zu Sicherheitszwecken. Die Verarbeitung
                  erfolgt auf Grundlage von Art. 6 Abs. 1 lit. f DSGVO. Das
                  berechtigte Interesse liegt in der sicheren, stabilen und
                  fehlerfreien Bereitstellung der Website.
                </p>
                <p>
                  GitHub kann Daten auch in den USA und anderen Drittländern
                  verarbeiten. GitHub nennt hierfür insbesondere das EU-US Data
                  Privacy Framework und die EU-Standardvertragsklauseln als
                  Übermittlungsgrundlagen. Weitere Informationen finden Sie in
                  der{" "}
                  <a
                    href="https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Datenschutzerklärung von GitHub
                  </a>
                  .
                </p>

                <h3>3. Kontaktaufnahme per E-Mail</h3>
                <p>
                  Bei einer Kontaktaufnahme per E-Mail werden die von Ihnen
                  übermittelten Angaben einschließlich Inhalt und Kontaktdaten
                  verarbeitet, um Ihre Anfrage zu beantworten. Rechtsgrundlage
                  ist Art. 6 Abs. 1 lit. b DSGVO, soweit es um vorvertragliche
                  oder vertragliche Kommunikation geht, im Übrigen Art. 6 Abs.
                  1 lit. f DSGVO. Das berechtigte Interesse liegt in der
                  sachgerechten Bearbeitung Ihrer Anfrage.
                </p>

                <h3>4. Cookies, Tracking und externe Inhalte</h3>
                <p>
                  Diese Website setzt keine eigenen Cookies ein und verwendet
                  keine Analyse-, Werbe- oder Tracking-Dienste. Schriftarten,
                  Diagramme, Bilder und sonstige Seitenelemente werden lokal
                  bereitgestellt. Externe Websites werden erst aufgerufen,
                  wenn Sie einen entsprechend gekennzeichneten Link anklicken.
                  Ab diesem Zeitpunkt gelten die Datenschutzbestimmungen des
                  jeweiligen Anbieters.
                </p>

                <h3>5. Speicherdauer</h3>
                <p>
                  E-Mail-Anfragen werden gelöscht, sobald sie abschließend
                  bearbeitet sind und keine gesetzlichen Aufbewahrungsfristen
                  oder berechtigten Interessen entgegenstehen. Die
                  Speicherdauer technischer Protokolldaten richtet sich nach
                  den Vorgaben des Hosting-Anbieters.
                </p>

                <h3>6. Ihre Rechte</h3>
                <p>
                  Sie haben nach Maßgabe der gesetzlichen Voraussetzungen
                  Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung
                  der Verarbeitung, Datenübertragbarkeit und Widerspruch.
                  Erteilte Einwilligungen können jederzeit mit Wirkung für die
                  Zukunft widerrufen werden.
                </p>
                <p>
                  Zudem besteht ein Beschwerderecht bei einer
                  Datenschutzaufsichtsbehörde. Zuständig ist insbesondere das{" "}
                  <a
                    href="https://www.lda.bayern.de/de/beschwerde.html"
                    target="_blank"
                    rel="noreferrer"
                  >
                    Bayerische Landesamt für Datenschutzaufsicht
                  </a>,{" "}
                  Promenade 18, 91522 Ansbach.
                </p>

                <h3>7. Transportverschlüsselung</h3>
                <p>
                  Die Website wird verschlüsselt über HTTPS übertragen.
                  E-Mail-Kommunikation ist ohne zusätzliche Maßnahmen nicht
                  Ende-zu-Ende verschlüsselt; senden Sie daher keine besonders
                  sensiblen Daten unverschlüsselt per E-Mail.
                </p>
                <p className="legal-updated">Stand: 29. Juli 2026</p>
              </>
            )}

            {legalPanel === "impressum" && (
              <>
                <p className="eyebrow">Impressum</p>
                <h2>Angaben gemäß § 5 DDG</h2>
                <address>
                  Christoph Gschnaidtner
                  <br />
                  Am Steinberg 40
                  <br />
                  82237 Wörthsee
                  <br />
                  Deutschland
                </address>

                <h3>Kontakt</h3>
                <p>
                  E-Mail:{" "}
                  <a href="mailto:meinKrypto@christoph-gschnaidtner.de">
                    meinKrypto@christoph-gschnaidtner.de
                  </a>
                </p>

                <h3>Redaktionell verantwortlich</h3>
                <address>
                  Verantwortlich für journalistisch-redaktionelle Inhalte
                  gemäß § 18 Abs. 2 MStV:
                  <br />
                  Christoph Gschnaidtner
                  <br />
                  Am Steinberg 40
                  <br />
                  82237 Wörthsee
                  <br />
                  Deutschland
                </address>

                <h3>Haftung für externe Links</h3>
                <p>
                  Diese Website enthält Links zu externen Websites Dritter. Auf
                  deren Inhalte besteht kein Einfluss; verantwortlich ist der
                  jeweilige Anbieter. Zum Zeitpunkt der Verlinkung waren keine
                  Rechtsverstöße erkennbar. Bei Bekanntwerden konkreter
                  Rechtsverletzungen werden betroffene Links entfernt.
                </p>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
