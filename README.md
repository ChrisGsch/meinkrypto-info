# meinKrypto.info

Responsive Informations- und Veranstaltungswebsite zu Bitcoin, Ethereum,
Cardano und Litecoin. Das Projekt enthält zwei technisch gleichwertige
Ausgabewege:

- die Next-/Vinext-Website für den bereitgestellten Hosting-Stand
- einen statischen Vite-Build für GitHub Pages und die Domain
  `meinkrypto.info`

## Inhalte

- Marktüberblick für BTC, ETH, ADA und LTC
- Monatsrenditen, Korrelationen, Bitcoin-/Gold-Vergleich und Volatilität
- kuratierte Entwicklungen mit Primärquellen
- Veranstaltungsformate aus der Kundenveranstaltungsübersicht
- Kontakt, Risikohinweis, Datenschutz und Impressumsgrundlage

## Lokale Nutzung

Voraussetzung: Node.js 22 oder neuer.

```bash
npm ci
npm run dev
```

Der statische GitHub-Pages-Build wird mit folgendem Befehl erzeugt:

```bash
npm run build:pages
```

Die fertigen Dateien liegen danach unter `dist-pages/`.

## Tägliche Datenaktualisierung

`scripts/update_market_data.R` lädt Marktdaten über Yahoo Finance sowie
Makrodaten mit `fredr::fredr()` und erzeugt:

- `public/data/market.json`
- kompakte 365-Tage-Kursverläufe für die Marktübersicht
- monatliche Rendite-Heatmaps
- Korrelationsmatrizen mit Krypto-, Aktien-, Währungs- und Rohstoffwerten
- Bitcoin-/Gold-Vergleiche
- rollierende 30-Tage-Volatilität
- überlagerte Bitcoin-/Inflations- und Bitcoin-/Leitzins-Grafiken mit zwei
  y-Achsen

Der Workflow `.github/workflows/deploy-pages.yml` führt diese Aktualisierung
jeden Tag stündlich von 05:02 Uhr bis einschließlich 22:02 Uhr deutscher Zeit
aus und veröffentlicht den neuen Stand anschließend auf GitHub Pages. Die
Zeitzone `Europe/Berlin` berücksichtigt Sommer- und Winterzeit automatisch.

Jede der 21 Datenreihen wird unabhängig abgerufen, geprüft und in einer eigenen
Last-known-good-Datei unter `data/market-cache/` gespeichert. Schlägt nur eine
Reihe fehl, werden die übrigen Reihen trotzdem aktualisiert. Für die fehlende
Reihe wird nach drei Abrufversuchen der letzte validierte Cache verwendet. Neue
Dateien ersetzen den bestehenden Stand erst nach erfolgreicher Validierung und
werden mit einer Sicherungsdatei geschrieben. GitHub Actions stellt den Cache
beim nächsten Lauf wieder her.

Der technische Datenstatus steht in `public/data/update-status.json`; ein
ausführliches Laufprotokoll wird als GitHub-Actions-Artefakt bereitgestellt.
Eine sichtbare Meldung auf der Website erscheint erst, wenn Daten kritisch alt
sind oder eine Darstellung nicht sicher neu erzeugt werden konnte. Details
stehen in [DATEN-FALLBACK.md](DATEN-FALLBACK.md).

## Aktuelle Einordnungen pflegen

Die redaktionellen Einordnungen liegen in
`public/data/insights.json`. Sie werden bewusst nicht automatisch von einer KI
geschrieben oder veröffentlicht. Die Datei kann direkt auf GitHub bearbeitet
werden; nach dem Speichern baut der Workflow die Website automatisch neu.

Eine Schritt-für-Schritt-Anleitung steht in
[EINORDNUNGEN-PFLEGEN.md](EINORDNUNGEN-PFLEGEN.md).

## Vor der öffentlichen Veröffentlichung

1. Kontaktangaben, Quellen und Risikohinweise vor jeder Veröffentlichung
   abschließend prüfen.
2. Die Schritte in [LIVE-SCHALTUNG.md](LIVE-SCHALTUNG.md) ausführen.

Die Inhalte sind Informationen und keine Anlageberatung.
