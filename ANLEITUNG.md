# E&P Team-Analyzer – Anleitung Schritt für Schritt

Von **FGSeRaser** – [github.com/FGSeRaser](https://github.com/FGSeRaser)

Diese Anleitung erklärt alles: vom Hochladen auf GitHub über die fertige APK bis zur Bedienung der App.
Du brauchst **kein Flutter auf deinem PC** – GitHub baut die App für dich.

---

## Inhalt

1. [Was du brauchst](#1-was-du-brauchst)
2. [Projekt auf GitHub hochladen](#2-projekt-auf-github-hochladen)
3. [GitHub einmalig einstellen](#3-github-einmalig-einstellen)
4. [APK bauen lassen und herunterladen](#4-apk-bauen-lassen-und-herunterladen)
5. [App auf dem Handy installieren](#5-app-auf-dem-handy-installieren)
6. [Die App benutzen](#6-die-app-benutzen)
7. [Helden per Screenshot einlesen – so klappt es am besten](#7-helden-per-screenshot-einlesen)
8. [Updates: neue Helden und neue App-Versionen](#8-updates)
9. [Sicherung deiner Sammlung](#9-sicherung-deiner-sammlung)
10. [Wenn etwas nicht klappt](#10-wenn-etwas-nicht-klappt)
11. [Wichtig zu wissen](#11-wichtig-zu-wissen)
12. [Für später: lokal am PC bauen](#12-für-später-lokal-am-pc-bauen)

---

## 1. Was du brauchst

- Einen **GitHub-Account** (hast du: FGSeRaser)
- Einen **PC** zum Hochladen (am Handy geht das Hochladen von Ordnern schlecht)
- Ein **Android-Handy** (ab Android 7 sollte reichen)
- Die Datei **EP-Team-Analyzer.zip**

## 2. Projekt auf GitHub hochladen

### Weg A – im Browser (am einfachsten)

1. ZIP auf dem PC **entpacken**. Du bekommst den Ordner `ep_team_analyzer`.
2. Auf github.com oben rechts auf **„+“ → „New repository“**.
3. Name: zum Beispiel `EP-Team-Analyzer`
   - **Public** auswählen (die Daten von HeroPlan stehen unter GPL – öffentlich passt dazu; außerdem sind GitHub Actions für öffentliche Repos kostenlos)
   - **Keinen** Haken bei „Add a README“, „.gitignore“ oder „License“ (ist alles schon dabei)
   - **„Create repository“** klicken
4. Auf der leeren Repo-Seite auf den Link **„uploading an existing file“** klicken.
5. Den **Inhalt** des Ordners `ep_team_analyzer` (nicht den Ordner selbst!) ins Browserfenster ziehen.
   - Wichtig: Der Ordner **`.github`** muss mit hoch. Er beginnt mit einem Punkt und ist im Windows-Explorer evtl. versteckt.
     → Im Explorer oben auf **„Anzeigen“ → „Ausgeblendete Elemente“** einschalten.
   - Prüfe nach dem Hochziehen in der Liste, dass `.github/workflows/apk.yml` und `.github/workflows/daten.yml` dabei sind.
6. Unten auf **„Commit changes“** klicken.

### Weg B – mit Git (wenn du Git installiert hast)

Im entpackten Ordner `ep_team_analyzer` eine Eingabeaufforderung öffnen:

```bash
git init
git add .
git commit -m "E&P Team-Analyzer v0.3"
git branch -M main
git remote add origin https://github.com/FGSeRaser/EP-Team-Analyzer.git
git push -u origin main
```

## 3. GitHub einmalig einstellen

Damit der wöchentliche Daten-Update-Workflow neue Helden **selbst ins Repo schreiben** darf:

1. Im Repo auf **„Settings“** (Zahnrad oben).
2. Links **„Actions“ → „General“**.
3. Ganz unten bei **„Workflow permissions“**: **„Read and write permissions“** auswählen.
4. **„Save“** klicken.

Falls oben im Tab **„Actions“** eine Meldung kommt, dass Workflows aktiviert werden müssen: auf
**„I understand my workflows, go ahead and enable them“** klicken.

## 4. APK bauen lassen und herunterladen

Der Bau startet **automatisch nach jedem Hochladen**.

1. Im Repo oben auf den Tab **„Actions“**.
2. Links **„APK bauen“** auswählen. Oben steht der laufende Durchlauf (gelber Kreis = läuft).
3. Warten, bis ein **grüner Haken** erscheint. Das dauert beim ersten Mal ca. **10–15 Minuten**, danach meist 5–8.
4. Auf den Durchlauf klicken, ganz nach unten scrollen zu **„Artifacts“**.
5. **„EP-Team-Analyzer-APK“** herunterladen. Das ist eine ZIP-Datei.
6. ZIP entpacken → darin liegt **`app-release.apk`**.
7. Die APK aufs Handy bringen (USB-Kabel, Google Drive, E-Mail an dich selbst, Telegram an dich selbst …).

> Tipp: Du kannst den Bau auch von Hand starten: **Actions → „APK bauen“ → „Run workflow“**.
> Artifacts werden von GitHub nach 90 Tagen gelöscht – dann einfach neu bauen lassen.

**Roter Kreis statt grünem Haken?** → siehe [Abschnitt 10](#10-wenn-etwas-nicht-klappt).

## 5. App auf dem Handy installieren

1. Auf dem Handy die **`app-release.apk`** antippen (z. B. im Ordner „Downloads“ in der App „Dateien“).
2. Android fragt nach **„Unbekannte Apps installieren“** → für die App, mit der du die Datei öffnest
   (z. B. „Dateien“ oder Chrome), **erlauben**.
3. **„Installieren“** antippen.
4. Falls **Google Play Protect** warnt („App wurde nicht erkannt“): **„Mehr Details“ → „Trotzdem installieren“**.
   Das passiert bei jeder App, die nicht aus dem Play Store kommt.
5. Die App heißt auf dem Handy **„E&P Analyzer“**.

## 6. Die App benutzen

Unten gibt es fünf Bereiche: **Helden, Meine, Teams, Wissen, Info**.

### 👥 Helden
Alle Helden des Spiels mit Werten, Fähigkeiten und Passiven auf Deutsch.

- **Suchen**: oben Name, Titel oder Fähigkeitsname eintippen
- **Filtern**: Sterne, Farbe, „Kostüme“, „Kommende“ (noch nicht erschienene Helden), „Meine“ (nur deine)
- **„Effekte“-Knopf**: z. B. alle Helden mit *Bannen* UND *Reinigen*
- **Sortieren**: Symbol oben rechts (Kraft, Name, Neueste, Angriff …)
- **Held antippen** → Detailseite:
  - Werte bei Max / LB1 / LB2
  - Spezialfähigkeit, Passive, Familienbonus
  - **„Was er kann“** – antippen zeigt alle Helden mit diesem Effekt
  - **„Hilft dem Team gegen“** (echter Konter) und **„Federt ab“** (mildert nur)
  - **„Wird ausgehebelt durch“** – womit Gegner seine Stärke kontern
  - **„Zur Sammlung“** unten rechts

### 📦 Meine
Deine eigene Heldensammlung. Über **„Helden hinzufügen“**:

1. **Screenshots einlesen** – siehe [Abschnitt 7](#7-helden-per-screenshot-einlesen)
2. **Namen eintippen** – eine Zeile pro Held, z. B.
   ```
   Vivica
   2x Kiril
   Telluria x3, Proteus
   ```
   Tippfehler und englische Namen sind egal.
3. **Aus der Datenbank wählen** – Helden antippen (grüner Haken), dann oben **„Fertig“**

Danach kommt immer die **Prüf-Seite**: Für jeden Fund siehst du bis zu 5 Vorschläge.
Orange **„Unsicher – bitte prüfen“** heißt: kurz draufschauen. Mit **„Anderer …“** wählst du selbst.
Unten rechts **„… übernehmen“**.

Einen Helden in „Meine“ **antippen**, um Anzahl, Aufstiegsstufe, Level, Limit Break und Talent zu ändern
oder ihn zu entfernen.

**Sammlungs-Check** (aufklappen): zeigt für jede gegnerische Gefahr, wie viele deiner Helden sie kontern.
- 🔴 rot = keiner deiner Helden hilft
- 🟠 orange = nur abgefedert
- 🟡 gelb = 1–2 Konter
- 🟢 grün = gut abgedeckt
Antippen zeigt die Helden – und wenn dir etwas fehlt, welche Helden helfen würden.

### 🛡️ Teams
Drei Werkzeuge:

**Team-Builder** – baut aus *deinen* Helden die besten 5er-Teams:
1. Modus wählen: **Verteidigung**, **Angriff / Raid**, **Krieg (6 Teams)** oder **Titan**
2. Bei Titan die **Farbe des Titanen** wählen (die App nimmt dann Helden mit Farbvorteil)
3. **„Teams bauen“** – du bekommst das beste Team plus Alternativen mit Stärken (✔) und Schwächen (⚠)
4. Bei Verteidigung steht die **Aufstellung** dabei (Flanke, Flügel, Tank in der Mitte …)
5. Bei Krieg: 6 Teams, jeder Held nur einmal

**Gegner-Analyse** – „Mit welchen Helden schlage ich dieses Team?“
1. **„Screenshot vom Gegnerteam“** (z. B. vom Raid oder aus dem Krieg) – oder die 5 Plätze antippen und Helden wählen
2. Prüfen, ob alle 5 stimmen (antippen = ändern). Mitte = Tank
3. **„Beste Teams gegen diesen Gegner“** – die App zeigt deine besten Teams mit **geschätzter Gewinnchance in %**
   und erklärt warum (Farbvorteil gegen den Tank, welche Gegner-Effekte du konterst, wo du keine Antwort hast)

> Die Prozentzahl ist eine **Schätzung** (Stärke, Farben, Konter, Heilung) – kein Kampfsimulator.
> Steinglück und Truppen/Embleme des Gegners kann die App nicht kennen.

**Team-Check** – 5 Helden selbst wählen und Stärken/Lücken sehen (auch aus dem Builder heraus: „Im Team-Check öffnen“).

### 📖 Wissen
- **Effekte & Konter**: Konter-Tabelle und alle Effekte mit Anzahl Helden
- **Truppen**: alle Truppenarten (Mana, Krit, Magie, Styx, Ninja) mit Stufen, alle 20 legendären Truppen nach Klasse

Auf jeder **Heldenseite** steht jetzt auch **„Passende Truppen“**: welche epische Truppe für Angriff/Krieg,
Verteidigung und Titan, welche legendären Truppen zur Klasse passen und ab wie viel Mana-Bonus der Held einen Stein schneller ist.

### ℹ️ Info
**Sprache umschalten (Deutsch / English)**, Stand der Datenbank, Datenquelle, Link zu deinem GitHub.

## 7. Helden per Screenshot einlesen

### So machst du die Screenshots

1. Im Spiel: **Helden → Heldenliste** öffnen (die Ansicht mit 5 Karten nebeneinander, Name und STÄRKE unter jedem Bild).
2. Am besten **nach Stärke sortiert** lassen.
3. **Screenshot** machen (meist Power + Leiser gleichzeitig).
4. **Ein Stück weiterscrollen** – ruhig mit Überlappung – nächster Screenshot.
5. Wiederholen, bis du durch bist.

### So liest du sie ein

1. In der App: **Meine → Helden hinzufügen → Screenshots einlesen**.
2. **„Screenshots auswählen“** → alle Bilder auf einmal markieren.
3. Die App erkennt jedes Bild (ein paar Sekunden pro Bild). Unter jedem Bild siehst du das Raster:
   - **grüne Kästchen** = Held erkannt
   - **graue Kästchen** = nichts erkannt (z. B. Kopfzeile – das ist richtig so)
4. Liegen die Kästchen **nicht auf den Gesichtern**: **„Raster anpassen“** antippen und mit den Reglern verschieben,
   bis jedes Kästchen ein Gesicht umrahmt → **„Übernehmen“**.
5. Unten **„… Helden prüfen“** antippen.
6. Auf der Prüf-Seite:
   - **„gelesen: Labblub ✓“** = Name unter der Karte passt zum Bild – sehr sicher
   - **LVL / Talent / Stärke** werden mit übernommen
   - Schalter **„Screenshots überlappen“** an lassen: gleicher Held mit gleicher Stärke zählt nur einmal,
     gleicher Held mit **anderer** Stärke (z. B. zwei Chitrangadas) zählt doppelt
   - Schalter **„Schon vorhandene nicht doppelt zählen“** an lassen, wenn du später nochmal scannst
7. **„… übernehmen“** – fertig.

### Was erkannt wird

| Was | Woher | Hinweis |
|---|---|---|
| Welcher Held / welches Kostüm | Gesicht (Porträt) | funktioniert immer, auch ohne Text |
| Name | Texterkennung | bestätigt das Porträt |
| Level → Stufe & Limit Break | „LVL 90“ | 90 = LB2, 85 = LB1, 80 = max ohne LB |
| Talent | Zahl im Abzeichen | 1–25 |
| Stärke | Zahl unter „STÄRKE“ | inklusive Embleme und Kostüm, wird in „Meine“ angezeigt |
| Trainer-Helden | Gesicht | werden automatisch übersprungen |

Alles läuft **auf dem Handy** – es werden **keine Bilder hochgeladen**.

## 8. Updates

### Neue Helden (automatisch)
Der Workflow **„Heldendaten aktualisieren“** läuft **jeden Montag früh** von selbst:
er holt die neuesten Daten von HeroPlan, baut die Datenbank neu und – wenn es neue Helden gibt –
startet danach automatisch einen neuen APK-Bau.

Von Hand starten: **Actions → „Heldendaten aktualisieren“ → „Run workflow“**.

### Neue App-Version installieren
1. **Vorher eine Sicherung machen** (siehe Abschnitt 9) – nur zur Vorsicht.
2. Neue APK wie in [Abschnitt 4](#4-apk-bauen-lassen-und-herunterladen) herunterladen.
3. Einfach **drüber installieren**. Deine Sammlung bleibt erhalten.

> Das klappt, weil jede APK mit demselben Schlüssel signiert wird (Ordner `android-signatur`).
> **Diesen Ordner nicht löschen** – sonst muss die alte App erst deinstalliert werden, und dabei geht die Sammlung verloren.

## 9. Sicherung deiner Sammlung

Die Sammlung liegt nur auf deinem Handy. So sicherst du sie:

1. **Meine → ⋮ (oben rechts) → „Sicherung kopieren“**
2. Der Text ist jetzt in der Zwischenablage → irgendwo einfügen und speichern
   (z. B. Notiz-App, Nachricht an dich selbst, Google Keep)

Zurückholen: **Meine → ⋮ → „Sicherung einfügen“** → Text einfügen → **„Importieren“**.
Achtung: Das **ersetzt** die aktuelle Sammlung.

So kannst du deine Sammlung auch auf ein **neues Handy** umziehen.

## 10. Wenn etwas nicht klappt

### Der Bau auf GitHub ist rot
1. Auf den roten Durchlauf klicken → auf **„build“** klicken.
2. Den Schritt mit dem **roten X** aufklappen.
3. Die **roten Fehlerzeilen** kopieren (oder Screenshot) und mir schicken – ich behebe das.

Häufige Ursachen:
- `.github`-Ordner fehlt → es läuft gar kein Bau → [Abschnitt 2](#2-projekt-auf-github-hochladen), Punkt 5
- „Permission denied“ beim Daten-Update → [Abschnitt 3](#3-github-einmalig-einstellen)

### „App nicht installiert“
- Es ist noch eine **ältere Version mit anderer Signatur** drauf → alte App deinstallieren
  (vorher **Sicherung** machen!), dann neu installieren.
- Zu wenig Speicher frei.

### Screenshot: kaum oder falsche Helden erkannt
- **„Raster anpassen“** und die Kästchen genau auf die Gesichter legen.
- Nur Screenshots der **Heldenliste** verwenden (keine Detailansicht, keine Teamauswahl).
- Keine bearbeiteten/zugeschnittenen Bilder – Original-Screenshots sind am besten.
- Falsche Vorschläge auf der Prüf-Seite einfach mit **„Anderer …“** korrigieren.
- Klappt es gar nicht: schick mir den Screenshot, dann stimme ich die Erkennung darauf ab.

### Level / Stärke fehlen auf der Prüf-Seite
Dann hat die Texterkennung auf deinem Handy nicht funktioniert. Die Helden werden trotzdem über das
Gesicht erkannt; Level & Co. kannst du in „Meine“ von Hand einstellen.

### Heldenbilder werden nicht angezeigt
Die Bilder werden aus dem Internet (HeroPlan) geladen → Internetverbindung prüfen.
Die Erkennung selbst braucht **kein** Internet.

## 11. Wichtig zu wissen

- **Werte**: Die App rechnet Angriff/Verteidigung/Leben exakt nach der Spielformel – aber **ohne Embleme und Kostümbonus**.
  Die **Stärke aus dem Screenshot** enthält dagegen alles.
- **„Echter Konter“ vs. „federt ab“**: Reinigen *entfernt* Mana-Verlangsamung (echter Konter),
  Mana-Boost *gleicht sie nur etwas aus* (federt ab). Die App rechnet bewusst nichts schön.
- **Kommende Helden**: Helden mit Termin in der Zukunft oder noch ohne Termin sind markiert („bald“).
  Bei manchen ist die Fähigkeit im Spiel noch ein Platzhalter – das steht dann auf der Detailseite.
- **Kostüme** werden als eigener Eintrag geführt (z. B. „Vivica (C1)“, „Isarnia (Glas)“, „Sartana (Stilvoll)“),
  weil sie andere Fähigkeiten haben.
- **Datenquelle**: HeroPlan (heroplan.github.io), ausgelesen aus den offiziellen Spieldateien.
  Abgeglichen mit empuzzled: alle sammelbaren Helden sind enthalten.
- **Lizenz**: GPL-3.0 (wegen der HeroPlan-Daten). Das Repo sollte deshalb öffentlich sein.
- **Signatur-Schlüssel** (`android-signatur/debug.keystore`): nur für diese App. Er sorgt dafür, dass Updates
  ohne Deinstallieren gehen. Nicht für andere Apps verwenden.
- Empires & Puzzles ist eine Marke von Small Giant Games – dies ist ein **inoffizielles Fan-Tool**.

## 12. Für später: lokal am PC bauen

Nur nötig, wenn du selbst am Code arbeiten willst.

1. Flutter installieren: <https://docs.flutter.dev/get-started/install/windows>
2. Android Studio installieren (für das Android-SDK), dann `flutter doctor` ausführen und alles grün machen.
3. Im Projektordner:
   ```bash
   flutter create --project-name ep_team_analyzer --org de.fgseraser --platforms android .
   del test\widget_test.dart
   python tools\android_anpassen.py
   flutter pub get
   flutter test
   flutter run            # App direkt aufs per USB verbundene Handy
   flutter build apk --release
   ```

### Projektaufbau

| Ordner / Datei | Inhalt |
|---|---|
| `lib/daten/` | Heldendatenbank, Analyse, Werteformel, Sammlung, Namenssuche |
| `lib/erkennung/` | Screenshot-Erkennung (Porträts, Raster, Texterkennung) |
| `lib/ui/` | alle Bildschirme der App |
| `assets/data/` | `helden.json` (alle Helden), `portraits.json/.bin` (Gesichts-Fingerabdrücke) |
| `tools/wissen.py` | **Effekte und Konter-Regeln** – hier kann man das „Wissen“ der App anpassen |
| `tools/build_helden_db.py` | baut `helden.json` aus den HeroPlan-Daten |
| `tools/build_portraits.py` | baut die Gesichts-Fingerabdrücke |
| `tools/test_erkennung.py` | testet die Erkennung (nachgebaute + echte Screenshots in `tools/testbilder/`) |
| `.github/workflows/apk.yml` | baut die APK bei jedem Hochladen |
| `.github/workflows/daten.yml` | holt jeden Montag neue Heldendaten |
| `android-signatur/` | fester Signatur-Schlüssel für Updates |

---

**Geplant:** automatische Teamvorschläge für Verteidigung, Angriff, Krieg und Titan aus deiner Sammlung –
und danach die Anbindung an den Discord-Allianz-Bot.
