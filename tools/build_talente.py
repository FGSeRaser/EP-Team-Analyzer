#!/usr/bin/env python3
"""
E&P Team-Analyzer – Talent-Raster (Embleme) aller 10 Klassen bauen
Autor: FGSeRaser – https://github.com/FGSeRaser

Quelle: HeroPlan (https://heroplan.github.io, GPL-3.0), Datei talent-tree.js.
Ausgabe: assets/data/talente.json

    python3 tools/build_talente.py <pfad-zum-heroplan-repo> [ausgabe.json]
"""
import json
import re
import sys
from pathlib import Path

STAT = {"攻击": "atk", "防御": "def", "生命": "hp", "法力": "mana", "治疗": "heal", "暴击": "crit"}

# Gabelungen (Pfad 1 = linke Seite im Spiel, Pfad 2 = rechte Seite)
GABELUNGEN = [
    (["2_1", "3_1"], ["2_2", "3_2"]),
    (["5_1", "6_1"], ["5_2", "6_2"]),
    (["8_1", "9_1"], ["8_2", "9_2"]),
    (["11_1"], ["11_2"]),
    (["13_1", "14_1"], ["13_2", "14_2"]),
    (["16_1", "17_1"], ["16_2", "17_2"]),
    (["19_1"], ["19_2"]),
    (["21_1", "22_1"], ["21_2", "22_2"]),
    (["24_1"], ["24_2"]),
]


def knoten(text):
    m = re.match(r"^(攻击|防御|生命|法力|治疗|暴击)\s*\+?(\d+)\s*(%)?$", text.strip())
    if not m:
        return {"t": "talent"}  # Klassen-Talent-Knoten
    return {"t": STAT[m.group(1)], "v": int(m.group(2)), "p": bool(m.group(3))}


def main():
    repo = Path(sys.argv[1])
    ziel = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).resolve().parent.parent / "assets/data/talente.json"
    js = (repo / "talent-tree.js").read_text(encoding="utf-8")

    master = {}
    m = re.search(r"const masterTalentData = (\{.*?\});", js)
    for nid, text in re.findall(r"'(\d+_\d)':\s*\{\s*text:\s*'([^']*)'", m.group(1)):
        master[nid] = knoten(text)

    klassen = {}
    for key, block in re.findall(r"'(\w+)':\s*\{\s*name:\s*'[^']*',\s*key:\s*'\w+',\s*data:\s*(\{.*?\})\s*\}", js):
        daten = {nid: knoten(text) for nid, text in re.findall(r"'(\d+_\d)':\s*\{\s*text:\s*'([^']*)'", block)}
        daten.update(master)
        pflicht = sorted(
            (nid for nid in daten if nid.endswith("_1") and nid.replace("_1", "_2") not in daten),
            key=lambda x: int(x.split("_")[0]),
        )
        klassen[key] = {
            "pflicht": [dict(daten[n], n=int(n.split("_")[0])) for n in pflicht],
            "gabel": [
                {
                    "l": [dict(daten[n], n=int(n.split("_")[0])) for n in l],
                    "r": [dict(daten[n], n=int(n.split("_")[0])) for n in r],
                }
                for l, r in GABELUNGEN
            ],
        }
    assert len(klassen) == 10, sorted(klassen)
    ziel.write_text(json.dumps({"quelle": "HeroPlan (GPL-3.0)", "klassen": klassen}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(klassen)} Klassen -> {ziel}")


if __name__ == "__main__":
    main()
