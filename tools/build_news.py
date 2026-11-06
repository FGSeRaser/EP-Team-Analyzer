#!/usr/bin/env python3
"""
E&P Team-Analyzer – offizielle News sammeln
Autor: FGSeRaser – https://github.com/FGSeRaser

Holt die Artikelliste von https://www.empiresandpuzzles.com/news, liest die neuesten
Artikel, ordnet sie ein (Balance, Version/Patch, Kalender, Statistik, Event …) und
schreibt news/news.json. Die App lädt diese Datei beim Öffnen des News-Tabs.

    python3 tools/build_news.py [ausgabe.json]
"""
import datetime as dt
import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

BASIS = "https://www.empiresandpuzzles.com"
SEITEN = [f"{BASIS}/news?page=0", f"{BASIS}/news?page=1"]
DETAILS = 15  # so viele neueste Artikel komplett lesen
MONATE = {m: i for i, m in enumerate(
    ["january", "february", "march", "april", "may", "june", "july",
     "august", "september", "october", "november", "december"], 1)}

ARTEN = [
    ("balance", r"\b(balanc|buff|nerf|rework|adjustment|hero changes|hero updates)"),
    ("version", r"\b(release notes|version \d+|patch|update \d|maintenance|hotfix|known issues)"),
    ("kalender", r"\b(calendar|schedule)"),
    ("statistik", r"\b(scrolls of aggregation|most used|statistics|stats)"),
    ("event", r"\b(event|festival|season|tournament|challenge|war|titan|quest|summon|portal)"),
]


def holen(url):
    req = urllib.request.Request(url, headers={"User-Agent": "EP-Team-Analyzer-News/1.0 (+github.com/FGSeRaser)"})
    for versuch in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001
            if versuch == 2:
                print(f"Fehler bei {url}: {e}", file=sys.stderr)
                return ""
            time.sleep(3)
    return ""


def text_aus(fragment):
    fragment = re.sub(r"(?is)<(script|style|noscript)[^>]*>.*?</\1>", " ", fragment)
    fragment = re.sub(r"(?i)<br\s*/?>", "\n", fragment)
    fragment = re.sub(r"(?i)</(p|div|li|h[1-6]|tr)>", "\n", fragment)
    fragment = re.sub(r"(?i)<li[^>]*>", "• ", fragment)
    t = html.unescape(re.sub(r"<[^>]+>", " ", fragment))
    t = re.sub(r"[ \t ]+", " ", t)
    t = re.sub(r"\n\s*\n+", "\n\n", t)
    return "\n".join(z.strip() for z in t.split("\n")).strip()


DATUM = re.compile(r"(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2}),\s*(\d{4})", re.I)


def liste():
    artikel = {}
    for url in SEITEN:
        seite = holen(url)
        for m in re.finditer(r'(?is)<a[^>]+href="(?:https://www\.empiresandpuzzles\.com)?(/news/[a-z0-9][a-z0-9\-]*)"[^>]*>(.*?)</a>', seite):
            pfad, inhalt = m.group(1), text_aus(m.group(2))
            inhalt = re.sub(r"\s+", " ", inhalt).strip()
            d = DATUM.search(inhalt)
            if not d:
                continue
            titel = (inhalt[:d.start()] + inhalt[d.end():]).strip(" -–|·")
            if not titel:
                continue
            datum = dt.date(int(d.group(3)), MONATE[d.group(1).lower()], int(d.group(2))).isoformat()
            artikel.setdefault(pfad, {"titel": titel, "datum": datum, "url": BASIS + pfad})
    return sorted(artikel.values(), key=lambda a: a["datum"], reverse=True)


def artikel_text(url):
    seite = holen(url)
    if not seite:
        return "", ""
    beschreibung = ""
    m = re.search(r'(?is)<meta[^>]+(?:property|name)="(?:og:)?description"[^>]+content="([^"]*)"', seite)
    if m:
        beschreibung = html.unescape(m.group(1)).strip()
    # Hauptinhalt: <article> oder <main>, sonst der ganze Body
    m = re.search(r"(?is)<article[^>]*>(.*?)</article>", seite) or re.search(r"(?is)<main[^>]*>(.*?)</main>", seite)
    roh = m.group(1) if m else seite
    text = text_aus(roh)
    # Werbe-/Navigationszeilen entfernen
    weg = re.compile(r"^(WEB ONLY|CLAIM GIFT|Claim gift|About|Store|Daily Streak|News|Redeem|Plus|E&P Discord|Guides|FAQ)\b.*$", re.I)
    zeilen = [z for z in text.split("\n") if not weg.match(z.strip())]
    text = "\n".join(zeilen).strip()
    return beschreibung, text[:8000]


def einordnen(titel, text):
    ges = f"{titel}\n{text}".lower()
    arten = [a for a, muster in ARTEN if re.search(muster, titel.lower())]
    # Balance auch dann, wenn es im Text eine Balance-Überschrift gibt
    if "balance" not in arten and re.search(r"(hero balance|balance changes|balance update|buffs? (to|for)|nerfs? (to|for))", ges):
        arten.insert(0, "balance")
    return arten or ["info"]


EVENT_ZEILE = re.compile(
    r"^[•\-*]?\s*(?P<sm>[A-Za-z]+)\s+(?P<sd>\d{1,2}),?\s*(?P<st>\d{1,2}:\d{2})\s*UTC\s*(?:→|->|–|-|to)\s*"
    r"(?P<em>[A-Za-z]+)\s+(?P<ed>\d{1,2}),?\s*(?P<et>\d{1,2}:\d{2})\s*UTC\s*:\s*(?P<name>.+)$")


def _zeit(monat, tag, uhr, jahr):
    h, m = (int(x) for x in uhr.split(":"))
    return dt.datetime(jahr, MONATE[monat.lower()], int(tag), h, m, tzinfo=dt.timezone.utc)


def kalender_aus(artikel):
    """Termine aus den offiziellen „Calendar of Events“-Artikeln"""
    termine, regeln = {}, []
    for a in sorted((x for x in artikel if "kalender" in x.get("arten", []) and x.get("text")), key=lambda x: x["datum"]):
        jahr_artikel = int(a["datum"][:4])
        monat_artikel = int(a["datum"][5:7])
        neue_regeln = []
        for zeile in a["text"].split("\n"):
            z = zeile.strip()
            m = EVENT_ZEILE.match(z)
            if m and m.group("sm").lower() in MONATE and m.group("em").lower() in MONATE:
                sm = MONATE[m.group("sm").lower()]
                jahr = jahr_artikel + (1 if sm < monat_artikel - 6 else 0)
                start = _zeit(m.group("sm"), m.group("sd"), m.group("st"), jahr)
                ende = _zeit(m.group("em"), m.group("ed"), m.group("et"), jahr)
                if ende < start:
                    ende = ende.replace(year=ende.year + 1)
                roh = m.group("name").strip()
                # Emoji/Symbole am Ende abtrennen
                name = re.sub(r"[^\w\s:'’&!\-.,()/]+$", "", roh).strip()
                symbol = roh[len(name):].strip()
                key = (name.lower(), start.isoformat())
                termine[key] = {
                    "name": name,
                    "symbol": symbol,
                    "start": start.strftime("%Y-%m-%dT%H:%MZ"),
                    "ende": ende.strftime("%Y-%m-%dT%H:%MZ"),
                    "artikel": a["url"],
                }
            elif re.search(r"\b(rotate|every|starting|each)\b", z, re.I) and 15 < len(z) < 300 and not z.lower().startswith("disclaimer"):
                neue_regeln.append(z)
        if neue_regeln:
            regeln = neue_regeln  # neuester Kalender gewinnt
    return sorted(termine.values(), key=lambda t: (t["start"], t["name"])), regeln


# ---------------------------------------------------------------------------
# Deutsch: Eventnamen aus einer festen Liste, Texte maschinell übersetzt
# ---------------------------------------------------------------------------

EVENT_DE = {
    "tavern of legends": "Taverne der Legenden",
    "costume chamber": "Kostümkammer",
    "charming costume chamber": "Charmante Kostümkammer",
    "goblin village": "Goblin-Dorf",
    "dragon cave": "Drachenhöhle",
    "vigilant vegetables": "Wachsames Gemüse",
    "contest of elements": "Wettstreit der Elemente",
    "astral plane": "Astralebene",
    "war of the three kingdoms": "Krieg der drei Königreiche",
    "monster island": "Monsterinsel",
    "mythic titan": "Mythischer Titan",
    "hero coach": "Heldentrainer",
    "windfall temple": "Tempel des Glücks",
    "hero league sign-up": "Heldenliga – Anmeldung",
    "hero league": "Heldenliga",
    "shadows of the deep": "Schatten der Tiefe",
    "covenant quest": "Bündnis-Quest",
    "black friday": "Black Friday",
    "ninja tower": "Ninja-Turm",
    "tower of magic": "Turm der Magie",
    "soul exchange": "Seelentausch",
    "ancient underroot": "Uralte Unterwurzel",
    "legendary troop quest": "Quest der legendären Truppen",
    "demon raiders": "Dämonen-Plünderer",
    "atlantis rises": "Atlantis erhebt sich",
    "valhalla forever": "Walhalla für immer",
    "tremors of underwild": "Beben der Unterwildnis",
    "judgment of dunes": "Urteil der Dünen",
    "untold tales": "Unerzählte Geschichten",
    "beach party": "Strandparty",
    "springvale": "Springvale",
    "pirates of corellia": "Piraten von Corellia",
    "winter festival": "Winterfest",
    "santa's challenge": "Weihnachtsmann-Herausforderung",
    "alliance quest": "Allianz-Quest",
    "raid tournament": "Raid-Turnier",
    "titan valley": "Titanental",
    "tournament": "Turnier",
}


def event_de(name):
    n = name.strip()
    k = n.lower()
    if k in EVENT_DE:
        return EVENT_DE[k]
    # "Alliance Quest: Clash of Knights" -> "Allianz-Quest: Clash of Knights" usw.
    for en in sorted(EVENT_DE, key=len, reverse=True):
        if k.startswith(en + ":") or k.startswith(en + " -") or k.startswith(en + " –"):
            return EVENT_DE[en] + n[len(en):]
    return ""


def _gtx(text):
    q = urllib.parse.urlencode({"client": "gtx", "sl": "en", "tl": "de", "dt": "t", "q": text})
    req = urllib.request.Request("https://translate.googleapis.com/translate_a/single?" + q,
                                 headers={"User-Agent": "Mozilla/5.0 (EP-Team-Analyzer News)"})
    with urllib.request.urlopen(req, timeout=30) as r:
        daten = json.loads(r.read().decode("utf-8"))
    return "".join(teil[0] for teil in daten[0] if teil and teil[0])


def uebersetzen(text):
    """Englisch -> Deutsch in Stücken (max. ~1800 Zeichen je Anfrage). Leer bei Fehler."""
    if not text or not text.strip():
        return ""
    stuecke, aktuell = [], ""
    for absatz in text.split("\n"):
        if len(aktuell) + len(absatz) + 1 > 1800 and aktuell:
            stuecke.append(aktuell)
            aktuell = ""
        aktuell += absatz + "\n"
    if aktuell:
        stuecke.append(aktuell)
    out = []
    for st in stuecke:
        # Zeilen über eine Markierung erhalten (gtx verschluckt sonst Zeilenumbrüche)
        roh = st.rstrip("\n").replace("\n", " ⏎ ")
        for versuch in range(3):
            try:
                t = _gtx(roh)
                break
            except Exception as e:  # noqa: BLE001
                if versuch == 2:
                    print(f"Übersetzung fehlgeschlagen: {e}", file=sys.stderr)
                    return ""
                time.sleep(4)
        out.append(re.sub(r"\s*⏎\s*", "\n", t))
        time.sleep(0.6)
    return "\n".join(out).strip()


def main():
    ziel = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "news/news.json"
    alt = {}
    if ziel.exists():
        try:
            alt = {a["url"]: a for a in json.loads(ziel.read_text(encoding="utf-8")).get("artikel", [])}
        except Exception:  # noqa: BLE001
            alt = {}
    neu = liste()
    if not neu:
        print("Keine Artikel gefunden – alte Datei bleibt.")
        return
    ausgabe = []
    for i, a in enumerate(neu[:40]):
        vorher = alt.get(a["url"])
        if vorher and vorher.get("text"):
            a.update({k: vorher[k] for k in ("kurz", "text", "titel_de", "kurz_de", "text_de") if k in vorher})
        elif i < DETAILS or re.search(r"(balanc|release notes|buff|nerf)", a["titel"].lower()):
            kurz, text = artikel_text(a["url"])
            a["kurz"], a["text"] = kurz, text
            time.sleep(1)
        a["arten"] = einordnen(a["titel"], a.get("text", ""))
        # Deutsch – nur einmal übersetzen, danach aus der alten Datei übernehmen
        if not a.get("titel_de") or (vorher and vorher.get("titel") != a["titel"]):
            a["titel_de"] = uebersetzen(a["titel"])
        if a.get("text") and not a.get("text_de"):
            a["text_de"] = uebersetzen(a["text"])
        if a.get("kurz") and not a.get("kurz_de"):
            a["kurz_de"] = uebersetzen(a["kurz"])
        ausgabe.append(a)
    termine, regeln = kalender_aus(ausgabe)
    alte_namen = {}
    alte_regeln = {}
    try:
        x = json.loads(ziel.read_text(encoding="utf-8")) if ziel.exists() else {}
        alte_namen = {t["name"]: t.get("name_de", "") for t in x.get("kalender", [])}
        alte_regeln = dict(zip(x.get("regeln", []), x.get("regeln_de", [])))
    except Exception:  # noqa: BLE001
        pass
    for t in termine:
        t["name_de"] = event_de(t["name"]) or alte_namen.get(t["name"]) or uebersetzen(t["name"]) or t["name"]
    regeln_de = [alte_regeln.get(rg) or uebersetzen(rg) or rg for rg in regeln]
    daten = {
        "quelle": "empiresandpuzzles.com/news",
        "stand": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
        "artikel": ausgabe,
        "kalender": termine,
        "regeln": regeln,
        "regeln_de": regeln_de,
    }
    ziel.parent.mkdir(parents=True, exist_ok=True)
    alt_ohne_stand = None
    if ziel.exists():
        try:
            x = json.loads(ziel.read_text(encoding="utf-8"))
            x.pop("stand", None)
            alt_ohne_stand = x
        except Exception:  # noqa: BLE001
            pass
    vergleich = dict(daten)
    vergleich.pop("stand")
    if alt_ohne_stand == vergleich:
        print("Keine Änderungen.")
        return
    ziel.write_text(json.dumps(daten, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(ausgabe)} Artikel -> {ziel}  (Balance: {sum('balance' in a['arten'] for a in ausgabe)})")


if __name__ == "__main__":
    main()
