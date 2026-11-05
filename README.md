# E&P Team-Analyzer

Android-App für **Empires & Puzzles**: kennt alle Helden mit Fähigkeiten, Passiven und Familienboni, weiß welche Effekte sich gegenseitig kontern und zeigt dir die Stärken und Lücken deiner Teams.

Von **FGSeRaser** – [github.com/FGSeRaser](https://github.com/FGSeRaser)

> 📘 **Neu hier? Lies zuerst die [ANLEITUNG.md](ANLEITUNG.md)** – Schritt für Schritt vom Hochladen bis zur Bedienung.

## Stand: Schicht 1 – das Heldenwissen

- **2.016 Helden** (1.343 Helden + 673 Kostüme) mit deutschen Texten
- Werte für Max, LB1 und LB2 (aus der offiziellen Wachstumsformel berechnet)
- Jede Spezialfähigkeit und Passive in **81 Effekte** zerlegt (Bannen, Reinigen, Mana-Verlangsamung, Spott …)
- **Konter-Tabelle**: welcher Effekt welchen wirklich aushebelt und was ihn nur abfedert
- Immunitäten aus Passiven (Toon, Glas, „Gift widerstehen“ usw.)
- Heldenliste mit Suche, Filtern (Sterne, Farbe, Kostüme, Effekte) und Sortierung
- Detailseite: Werte, Fähigkeiten, „Hilft gegen“, „Federt ab“, „Wird ausgehebelt durch“, Rollen-Eignung
- **Team-Check**: 5 Helden wählen → Grundbausteine, Hinweise, Lücken
- Abgleich mit empuzzled: alle sammelbaren Helden enthalten, dazu 134 kommende (auch ohne Termin)

## Stand: Schicht 2a – meine Helden

- **Screenshot-Erkennung**: Heldenliste im Spiel abfotografieren, mehrere Bilder auf einmal.
  Die App findet das Kartenraster selbst und vergleicht jedes Gesicht mit den Fingerabdrücken
  aller 2.133 Porträts (inkl. Kostüme). Trainer-Helden werden übersprungen. Raster von Hand nachjustierbar.
- **Texterkennung** (ML Kit, offline): liest unter jeder Karte Name, Level, Talent und Stärke –
  der Name bestätigt das Porträt, Level/Limit Break/Talent werden übernommen, und gleiche Helden
  mit unterschiedlicher Stärke zählen als eigene Exemplare.
- Getestet mit echten Screenshots der Heldenliste: 30/30 richtig (`tools/testbilder/`).
- **Namen eintippen**: Liste einfügen, Tippfehler und englische Namen werden erkannt, „2x Vivica“ geht auch.
- **Aus der Datenbank wählen** (Mehrfachauswahl)
- Prüf-Seite: Top-5-Vorschläge je Fund, unsichere markiert, überlappende Screenshots werden nicht doppelt gezählt
- Je Held: Anzahl, Aufstiegsstufe, Level, Limit Break, Talent → Werte exakt nach Spielformel
- **Sammlungs-Check**: wogegen deine ganze Sammlung gewappnet ist und wo dir Konter fehlen
- Team-Check wählt aus deinen eigenen Helden
- Sicherung kopieren/einfügen

## Stand: Schicht 3 – Teams, Truppen, Sprachen

- **Team-Builder**: beste Teams aus der eigenen Sammlung für Verteidigung (mit Aufstellung), Angriff, Krieg (6 Teams) und Titan (mit Farbvorteil)
- **Gegner-Analyse**: Gegnerteam per Screenshot oder Auswahl → beste eigene Teams mit geschätzter Gewinnchance und Begründung
- **Truppen**: alle Truppenarten, 20 legendäre Truppen mit Klassen/Passiv, Empfehlung je Held und Modus, Mana-Schwellen
- **Deutsch / Englisch** umschaltbar (Oberfläche und alle Heldentexte)
- Eigenes **App-Icon** (`tools/icon_bauen.py`)

## Geplant

- **Schicht 4:** Anbindung an den Discord-Allianz-Bot

## APK bekommen

Der GitHub-Workflow (`.github/workflows/apk.yml`) baut bei jedem Push automatisch die APK:
**Actions → letzter Lauf „APK bauen“ → Artifacts → EP-Team-Analyzer-APK**.

Lokal mit installiertem Flutter:

```bash
flutter create --project-name ep_team_analyzer --org de.fgseraser --platforms android .
rm -f test/widget_test.dart
python3 tools/android_anpassen.py
flutter pub get
flutter build apk --release
```

## Heldendaten aktualisieren

Wenn neue Helden erscheinen:

```bash
git clone --depth 1 https://github.com/heroplan/heroplan.github.io.git heroplan
python3 tools/build_helden_db.py heroplan
```

Das schreibt `assets/data/helden.json` neu. Die Effekt- und Konter-Regeln stehen in `tools/wissen.py`.
Danach die Porträt-Fingerabdrücke: `python3 tools/build_portraits.py heroplan` (braucht `pip install pillow`).

**Automatisch:** Der Workflow `daten.yml` macht das jeden Montag selbst und committet neue Daten –
dadurch wird auch gleich eine neue APK gebaut.

## Screenshot-Erkennung testen

```bash
python3 tools/test_erkennung.py heroplan              # nachgebaute Heldenliste
python3 tools/test_erkennung.py heroplan screenshot.png   # echter Screenshot
```

Die Python-Version (`tools/erkennung.py`) rechnet genau wie die App (`lib/erkennung/erkennung.dart`).

## Datenquelle & Lizenz

Heldendaten und Bilder: [HeroPlan](https://heroplan.github.io) (GPL-3.0), ausgelesen aus den offiziellen Spieldateien.
Deshalb steht auch dieses Projekt unter der **GPL-3.0** (siehe `LICENSE`).

Empires & Puzzles ist eine Marke von Small Giant Games. Inoffizielles Fan-Tool.
