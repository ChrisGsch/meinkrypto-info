# Aktuelle Einordnungen pflegen

Die Rubrik „Aktuelle Einordnung“ wird redaktionell gepflegt. Sie wird nicht
automatisch von einer KI erstellt oder veröffentlicht.

## Einordnung direkt auf GitHub ändern

1. Im Repository die Datei `public/data/insights.json` öffnen.
2. Rechts oben auf das Stiftsymbol **Edit this file** klicken.
3. Den gewünschten Eintrag ändern oder einen vorhandenen Eintrag kopieren.
4. Auf gültige JSON-Syntax achten:
   - Texte stehen in doppelten Anführungszeichen.
   - Zwischen zwei Einträgen steht ein Komma.
   - Nach dem letzten Eintrag steht kein Komma.
5. Unter **Commit changes** die Änderung speichern.
6. Unter **Actions** prüfen, ob
   **Website und Marktdaten veröffentlichen** erfolgreich abgeschlossen wurde.

## Felder eines Eintrags

```json
{
  "date": "30. Juli 2026",
  "label": "Regulierung",
  "title": "Kurze, aussagekräftige Überschrift",
  "copy": "Ein kompakter Einordnungstext mit ein bis zwei Sätzen.",
  "source": "Name der Primärquelle",
  "href": "https://www.beispiel.de/quelle"
}
```

- `date`: sichtbares Datum
- `label`: kurze Kategorie, zum Beispiel Regulierung, Bitcoin oder Banken
- `title`: Überschrift der Karte
- `copy`: kompakte Einordnung
- `source`: sichtbarer Quellenname
- `href`: vollständiger Link zur Quelle

Die Reihenfolge der Einträge in der Datei entspricht der Reihenfolge auf der
Website.

## Was automatisch läuft

Automatisch aktualisiert werden:

- Kurse und Marktkennzahlen
- 365-Tage-Grafiken
- Monats- und Tagesrenditen
- Volatilitäten
- Vergleichsgrafiken
- Makrografiken und Korrelationsmatrizen

Der GitHub-Workflow führt den R-Code täglich um 07:23 Uhr und 19:23 Uhr
deutscher Zeit aus.

## Sinnvoller KI-Einsatz

KI kann später neue Einordnungen und passende Primärquellen als Entwurf
vorschlagen. Eine automatische Veröffentlichung ohne Prüfung ist bei
Finanzmarkt-, Regulierungs- und Risikoinhalten nicht empfehlenswert. Der
sinnvolle Ablauf ist:

1. KI erstellt einen Entwurf mit Quellen.
2. Inhalt, Datum und Quelle werden manuell geprüft.
3. Erst der freigegebene Text wird in `insights.json` übernommen.
