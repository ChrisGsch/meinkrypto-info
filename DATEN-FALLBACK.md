# Sicherheitsmechanismus für Markt- und Makrodaten

Die Website behandelt jede Datenreihe unabhängig. Ein Ausfall von FRED, Yahoo
Finance oder eines einzelnen Symbols stoppt deshalb nicht mehr automatisch die
gesamte Aktualisierung.

## Ablauf je Datenreihe

1. Die Reihe wird bis zu dreimal abgerufen.
2. Der Download wird vor der Verwendung geprüft:
   - erwartete Spalten vorhanden,
   - Datums- und Zahlenwerte gültig,
   - ausreichend Beobachtungen vorhanden,
   - jüngstes Datum plausibel,
   - Verlauf gegenüber dem vorhandenen Cache nicht unerwartet verkürzt.
3. Neue und vorhandene Beobachtungen werden zusammengeführt; bei demselben
   Datum gewinnt der neu geladene Wert.
4. Erst der validierte Verlauf ersetzt die bisherige Cache-Datei.
5. Schlagen Abruf oder Prüfung fehl, wird nur für diese Reihe der letzte
   validierte Cache verwendet.

Die CSV-Dateien und Metadaten liegen lokal unter `data/market-cache/`. In
GitHub Actions wird dieser Ordner vor jedem Lauf wiederhergestellt und danach
erneut gespeichert. Der Cache enthält keine Zugangsdaten.

## Sichere Datei-Ersetzung

Neue Cache- und JSON-Dateien werden zunächst als temporäre Datei geschrieben
und erneut eingelesen. Beim Austausch wird die bisherige Datei kurz als
`.bak`-Sicherung behalten. Falls der Austausch scheitert, wird diese Sicherung
wiederhergestellt. Diagramme werden ebenfalls zuerst in eine temporäre Datei
gerendert und ersetzen die veröffentlichte Grafik erst, wenn eine nichtleere
Ausgabedatei vorliegt.

## Altersgrenzen

| Reihe | Warnstufe im Protokoll | Sichtbarer Hinweis |
| --- | ---: | ---: |
| tägliche Yahoo-Reihen | Cache älter als 3 Tage | älter als 7 Tage |
| FRED-Makroreihen | Cache älter als 14 Tage | älter als 45 Tage |

Ein kurzer Ausfall bleibt damit für Besucher unsichtbar. Bei kritisch alten
oder erstmals vollständig fehlenden Daten erscheint ein Hinweis unterhalb der
Marktkarten. Alte Grafiken werden nicht gelöscht; abhängige Darstellungen
behalten ihren letzten erfolgreich erzeugten Stand.

## Status und Protokoll

Der GitHub-Lauf gibt für jede Reihe einen Status aus:

- `updated`: Download, Prüfung und Cache-Aktualisierung erfolgreich
- `cache`: Download fehlgeschlagen oder unplausibel; gültiger Cache verwendet
- `unavailable`: weder neuer Download noch gültiger Cache vorhanden
- `updated_cache_write_failed`: aktuelle Daten verwendbar, Cache konnte aber
  nicht sicher ersetzt werden

Die Website liest den gekürzten, nichttechnischen Status aus
`public/data/update-status.json`. Das vollständige Protokoll liegt während des
Laufs unter `data/market-cache/latest-run.json` und wird in GitHub 30 Tage als
`market-update-report-...` bereitgestellt.

## Erster Lauf

Vor dem ersten erfolgreichen Abruf existieren noch keine Rohdaten-Caches. Wenn
einzelne Reihen dabei nicht erreichbar sind, bleiben deren bisherige Diagramme
und die letzte veröffentlichte Marktdatei bestehen. Jeder erfolgreiche
Einzelabruf legt bereits seinen eigenen Cache an; der nächste Lauf kann diese
Reihe sofort als Fallback verwenden.

Für die FRED-Reihen muss das GitHub-Secret `FRED_API_KEY` gesetzt sein. Lokal
wird derselbe Name in `~/.Renviron` verwendet. Der Schlüssel wird weder im
Cache noch im Protokoll gespeichert.
