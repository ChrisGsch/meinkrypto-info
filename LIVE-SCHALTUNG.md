# meinKrypto.info live schalten

Die kostengünstigste und für dieses Projekt passende Variante ist GitHub Pages:
Das Hosting ist für ein öffentliches Repository kostenlos, der vorhandene
R-Code kann täglich automatisiert laufen und die bei IONOS verwaltete Domain
bleibt bestehen.

## 1. Vor dem Upload prüfen

Vor einer öffentlichen Veröffentlichung bitte zwingend:

1. Krypto-E-Mail-Adresse und verlinkte Quellen prüfen.
2. Die rechtlichen Texte bei Bedarf fachlich prüfen lassen. Die mitgelieferten
   Texte sind eine technische Grundlage, keine Rechtsberatung.
3. Optional die aktuelle Veranstaltungsbroschüre unter
   `public/library/Website/2026_Übersicht_Kundenveranstaltungen_Krypto_Gschnaidtner.pdf`
   ersetzen. Der Dateiname muss unverändert bleiben, damit der Download-Link
   weiterhin funktioniert.

## 2. GitHub-Repository anlegen

1. Auf GitHub ein neues Repository anlegen, zum Beispiel
   `meinkrypto-info`.
2. Für kostenloses GitHub Pages das Repository auf **Public** stellen.
3. Den entpackten Website-Ordner in Visual Studio Code öffnen.
4. Im Terminal ausführen und `GITHUB-NAME` ersetzen:

```bash
git init
git add .
git commit -m "meinKrypto.info initial veröffentlichen"
git branch -M main
git remote add origin https://github.com/GITHUB-NAME/meinkrypto-info.git
git push -u origin main
```

Falls das Repository bereits initialisiert ist, nur den vorhandenen Remote
prüfen und anschließend committen und pushen.

## 3. GitHub Pages aktivieren

1. Im GitHub-Repository **Settings** öffnen.
2. Links unter **Code and automation** auf **Pages** klicken.
3. Unter **Build and deployment** als Source **GitHub Actions** auswählen.
4. Unter **Actions** den Workflow
   **Website und Marktdaten veröffentlichen** öffnen.
5. Beim ersten Mal bei Bedarf über **Run workflow** manuell starten.
6. Nach erfolgreichem Lauf erscheint zunächst eine Adresse nach dem Muster
   `https://GITHUB-NAME.github.io/meinkrypto-info/`.

### FRED-Schlüssel für Makrodaten hinterlegen

Für Inflation und Leitzinsen wird das R-Paket `fredr` eingesetzt. Dafür ist ein
kostenloser FRED-API-Schlüssel erforderlich:

1. Unter <https://fred.stlouisfed.org/docs/api/api_key.html> einen Schlüssel
   erstellen.
2. Im GitHub-Repository **Settings > Secrets and variables > Actions** öffnen.
3. **New repository secret** auswählen.
4. Name `FRED_API_KEY` und als Wert den persönlichen Schlüssel eintragen.

Der Schlüssel gehört nicht in den R-Code, nicht in eine Datei und nicht in
einen Commit. Fehlt er vorübergehend, laufen die Yahoo-Reihen trotzdem weiter;
die FRED-Reihen verwenden ihren letzten gültigen Cache.

Der Workflow baut die statische Website bei jedem Push neu. Zusätzlich läuft er
jeden Tag **stündlich von 05:02 Uhr bis einschließlich 22:02 Uhr deutscher
Zeit**. Die im Workflow hinterlegte Zeitzone `Europe/Berlin` stellt automatisch
auf Sommer- und Winterzeit um. Dabei werden Kurse, Renditen, Korrelationen,
Bitcoin-/Gold-Vergleiche, Volatilitäten und Makrografiken aktualisiert.

Beim ersten vollständig erfolgreichen Lauf wird unter GitHub Actions ein
Last-known-good-Cache aufgebaut. Danach kann jede Datenreihe unabhängig auf den
letzten validierten Stand zurückfallen. Der Cache wird zwischen den Läufen über
GitHub Actions wiederhergestellt; er enthält ausschließlich öffentliche
Markt- und Makrodaten, keine Zugangsschlüssel.

GitHub kann zeitgesteuerte Läufe bei hoher Auslastung um einige Minuten
verzögern. Der Computer muss dafür nicht eingeschaltet sein und RStudio muss
nicht geöffnet werden.

Wichtig: GitHub kann geplante Workflows in einem öffentlichen Repository nach
60 Tagen ohne Repository-Aktivität deaktivieren. Falls in diesem Zeitraum keine
Website-Änderung erfolgt, unter **Actions** den Workflow öffnen und bei Bedarf
über **Enable workflow** wieder aktivieren. Schon ein normaler Inhalts-Commit
setzt den Aktivitätszeitraum erneut in Gang.

## 4. Domain in GitHub eintragen

1. Wieder **Settings > Pages** öffnen.
2. Unter **Custom domain** `meinkrypto.info` eintragen und speichern.
3. Die DNS-Prüfung zunächst offen lassen; sie wird nach den IONOS-Schritten
   erfolgreich.

Bei der Veröffentlichung über GitHub Actions ist die Einstellung unter
**Settings > Pages** maßgeblich. Die Datei `public/CNAME` liegt zusätzlich als
Kompatibilitätsdatei bei, ist für diesen Veröffentlichungsweg aber nicht
erforderlich.

## 5. DNS bei IONOS einstellen

In IONOS:

1. **Menü > Domain & SSL** öffnen.
2. Bei `meinkrypto.info` über die drei Punkte **DNS** auswählen.
3. Vorhandene A-/AAAA-Einträge für die Hauptdomain prüfen. Einträge eines
   bisherigen Webhosting-Ziels müssen entfernt oder ersetzt werden.
4. Vier A-Records für die Hauptdomain anlegen. Als Hostname je nach
   IONOS-Ansicht `@` verwenden oder das Feld leer lassen:

| Typ | Hostname | Zeigt auf |
| --- | --- | --- |
| A | `@` bzw. leer | `185.199.108.153` |
| A | `@` bzw. leer | `185.199.109.153` |
| A | `@` bzw. leer | `185.199.110.153` |
| A | `@` bzw. leer | `185.199.111.153` |

5. Einen CNAME-Record für `www` anlegen:

| Typ | Hostname | Zeigt auf |
| --- | --- | --- |
| CNAME | `www` | `GITHUB-NAME.github.io` |

Wichtig:

- `GITHUB-NAME` durch den eigenen GitHub-Nutzernamen ersetzen.
- Beim CNAME **keinen** Repository-Namen und kein `https://` ergänzen.
- MX-, SPF-, DKIM- und sonstige E-Mail-Einträge nicht löschen.
- Keine Wildcard-Records wie `*.meinkrypto.info` für GitHub Pages verwenden.

## 6. HTTPS aktivieren

1. Nach der DNS-Umstellung zu **GitHub > Settings > Pages** zurückkehren.
2. Warten, bis die Domainprüfung erfolgreich ist. DNS-Änderungen können von
   wenigen Minuten bis zu 24 Stunden benötigen.
3. Anschließend **Enforce HTTPS** aktivieren.
4. `https://meinkrypto.info` und `https://www.meinkrypto.info` testen.

## 7. Künftige Änderungen

Normale Inhalts- oder Designänderungen:

```bash
git add .
git commit -m "Website aktualisiert"
git push
```

Jeder Push löst automatisch einen neuen Build aus. Die tägliche
Datenaktualisierung läuft unabhängig davon zwischen 05:02 Uhr und 22:02 Uhr
stündlich weiter.

### Aktuelle Einordnungen ändern

Die Karten unter „Aktuelle Einordnung“ stehen in
`public/data/insights.json`.

So lassen sie sich ohne lokale Entwicklungsumgebung direkt auf GitHub ändern:

1. Im Repository `public/data/insights.json` öffnen.
2. Rechts oben auf das Stiftsymbol **Edit this file** klicken.
3. Datum, Kategorie, Überschrift, Kurztext, Quellenname oder Quellenlink ändern.
4. Unter **Commit changes** eine kurze Beschreibung eingeben und bestätigen.
5. Unter **Actions** warten, bis der neue Website-Lauf grün abgeschlossen ist.

Die Einordnungen werden nicht automatisch von KI geschrieben. Das ist bewusst
so, damit keine ungeprüften Aussagen oder Quellen veröffentlicht werden. Eine
spätere KI-Unterstützung kann als Entwurfsworkflow ergänzt werden; die
Veröffentlichung sollte weiterhin erst nach manueller Freigabe erfolgen.

### Zeitpunkte des R-Laufs ändern

Die Zeiten stehen in `.github/workflows/deploy-pages.yml`:

```yaml
schedule:
  - cron: "02 5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22 * * *"
    timezone: "Europe/Berlin"
```

`02` steht für die Minute; die folgende Liste enthält die Stunden von 05 bis
22 Uhr. Werden beispielsweise nur 08:15 Uhr und 20:15 Uhr gewünscht, lautet
die Cron-Zeile `"15 8,20 * * *"`.

## Typische Fehler

### Domainprüfung schlägt fehl

- Prüfen, ob noch alte A- oder AAAA-Records für die Hauptdomain aktiv sind.
- Prüfen, ob `www` wirklich auf `GITHUB-NAME.github.io` zeigt.
- Einige Stunden warten und die Prüfung erneut auslösen.

### Diagramme wurden an einem Tag nicht aktualisiert

- Im Repository unter **Actions** den letzten Workflow öffnen.
- Im Schritt **Marktanalysen aktualisieren** steht für jede Reihe `updated`,
  `cache` oder `unavailable`.
- Der Workflow aktualisiert erreichbare Reihen weiter und verwendet für
  ausgefallene Reihen den letzten validierten Datenstand.
- Unter **Artifacts** kann das Protokoll `market-update-report-...`
  heruntergeladen werden.
- Über **Run workflow** kann später ein neuer Versuch gestartet werden.

### Website funktioniert unter der GitHub-Adresse, aber nicht unter der Domain

Das ist fast immer ein DNS- oder Zertifikatsthema. Die GitHub-Seite selbst ist
dann bereits korrekt gebaut.
