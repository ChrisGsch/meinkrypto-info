# meinKrypto.info

Responsive Informations- und Veranstaltungswebsite zu Bitcoin, Ethereum,
Cardano und Litecoin. Dieses Übergabepaket ist für den statischen Betrieb über
GitHub Pages und die Domain `meinkrypto.info` vorbereitet.

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

Der veröffentlichungsfertige GitHub-Pages-Build wird mit folgendem Befehl
erzeugt:

```bash
npm run build:pages
```

Die fertigen Dateien liegen danach unter `dist-pages/`.

## Tägliche Datenaktualisierung

`scripts/update_market_data.R` lädt Marktdaten über Yahoo Finance und erzeugt:

- `public/data/market.json`
- kompakte 365-Tage-Kursverläufe für die Marktübersicht
- monatliche Rendite-Heatmaps
- Korrelationsmatrizen mit Krypto-, Aktien-, Währungs- und Rohstoffwerten
- Bitcoin-/Gold-Vergleiche
- rollierende 30-Tage-Volatilität
- überlagerte Bitcoin-/Inflations- und Bitcoin-/Leitzins-Grafiken mit zwei
  y-Achsen

Der Workflow `.github/workflows/deploy-pages.yml` führt diese Aktualisierung
jeden Tag um 07:23 Uhr und 19:23 Uhr deutscher Zeit aus und veröffentlicht den
neuen Stand anschließend auf GitHub Pages. Die Zeitzone `Europe/Berlin`
berücksichtigt Sommer- und Winterzeit automatisch. Wenn ein Datenanbieter
vorübergehend nicht erreichbar ist, wird der zuletzt im Repository vorhandene
Datenstand weiter ausgeliefert.

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
