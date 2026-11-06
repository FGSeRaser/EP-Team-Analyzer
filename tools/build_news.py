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
            a.update({k: vorher[k] for k in ("kurz", "text") if k in vorher})
        elif i < DETAILS:
            kurz, text = artikel_text(a["url"])
            a["kurz"], a["text"] = kurz, text
            time.sleep(1)
        a["arten"] = einordnen(a["titel"], a.get("text", ""))
        ausgabe.append(a)
    daten = {
        "quelle": "empiresandpuzzles.com/news",
        "stand": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%MZ"),
        "artikel": ausgabe,
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
