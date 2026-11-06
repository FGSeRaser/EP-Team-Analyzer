#!/usr/bin/env python3
"""
E&P Team-Analyzer – assets/data/stand.json schreiben (Version + Prüfsummen)
Autor: FGSeRaser – https://github.com/FGSeRaser

Die App vergleicht beim Start die Version mit der auf GitHub und lädt nur
geänderte Dateien. Die Version ändert sich nur, wenn sich wirklich Daten ändern
(das Datum im Feld "version" von helden.json zählt nicht als Änderung).

    python3 tools/build_stand.py        -> Exit 0 = geändert, Exit 3 = unverändert
"""
import datetime as dt
import hashlib
import json
import sys
from pathlib import Path

ORDNER = Path(__file__).resolve().parent.parent / "assets/data"
DATEIEN = ["helden.json", "portraits.json", "portraits.bin", "talente.json"]


def summe(name):
    roh = (ORDNER / name).read_bytes()
    if name == "helden.json":
        d = json.loads(roh)
        d.pop("version", None)
        roh = json.dumps(d, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha1(roh).hexdigest()[:16]


def main():
    summen = {d: summe(d) for d in DATEIEN}
    pfad = ORDNER / "stand.json"
    alt = json.loads(pfad.read_text(encoding="utf-8")) if pfad.exists() else {}
    if alt.get("dateien") == summen and "--erzwingen" not in sys.argv:
        print("Daten unverändert.")
        sys.exit(3)
    version = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%MZ")
    pfad.write_text(json.dumps({"version": version, "dateien": summen}, indent=1), encoding="utf-8")
    print(f"Neuer Datenstand {version}")


if __name__ == "__main__":
    main()
