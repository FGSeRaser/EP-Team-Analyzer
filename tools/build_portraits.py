#!/usr/bin/env python3
"""
Erzeugt die Porträt-Fingerabdrücke für die Screenshot-Erkennung.
Autor: FGSeRaser – https://github.com/FGSeRaser

Aufruf:
    python3 tools/build_portraits.py <heroplan-repo>

Braucht im HeroPlan-Repo den Ordner imgs/hero_icon (Gesichtsporträts 166x225).
Schreibt:
    assets/data/portraits.json  – IDs und Parameter
    assets/data/portraits.bin   – je Held: TW*TH*3 Bytes Mini-Bild + BINS Bytes Histogramm
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import erkennung as E  # noqa: E402

HIER = os.path.dirname(os.path.abspath(__file__))
ZIEL = os.path.join(HIER, "..", "assets", "data")


class Pixel:
    """Zeilenweiser Zugriff px[y][x] -> (r,g,b,a), Transparenz auf dunkles Grau gelegt."""

    def __init__(self, im):
        im = im.convert("RGBA")
        hg = Image.new("RGBA", im.size, (30, 30, 30, 255))
        hg.alpha_composite(im)
        self.w, self.h = hg.size
        daten = list(hg.get_flattened_data() if hasattr(hg, "get_flattened_data") else hg.getdata())
        self.zeilen = [daten[y * self.w:(y + 1) * self.w] for y in range(self.h)]

    def __getitem__(self, y):
        return self.zeilen[y]


def fp_von_datei(pfad):
    px = Pixel(Image.open(pfad))
    return E.fingerabdruck(px, px.w, px.h, 0, 0, px.w, px.h)


def main():
    hp = sys.argv[1]
    icons = os.path.join(hp, "imgs", "hero_icon")
    helden = json.load(open(os.path.join(ZIEL, "helden.json"), encoding="utf-8"))["helden"]
    ids = [h["id"] for h in helden]
    trainer = sorted(f[:-5] for f in os.listdir(icons) if f.startswith("trainer_") and f.endswith(".webp"))

    eintraege, fehlt = [], []
    for hid in ids + trainer:
        pfad = os.path.join(icons, hid + ".webp")
        if not os.path.exists(pfad):
            fehlt.append(hid)
            continue
        mini, hist = fp_von_datei(pfad)
        eintraege.append((hid, mini, hist))

    roh = bytearray()
    for _, mini, hist in eintraege:
        roh.extend(min(255, max(0, round(v))) for v in mini)
        roh.extend(min(255, round(v * 255)) for v in hist)

    meta = {
        "tw": E.TW, "th": E.TH, "bins": E.BINS,
        "ausschnitt": list(E.AUSSCHNITT),
        "verhaeltnis": E.PORTRAET_VERHAELTNIS,
        "ids": [e[0] for e in eintraege],
        "trainer": [t for t in trainer if t in {e[0] for e in eintraege}],
    }
    with open(os.path.join(ZIEL, "portraits.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, separators=(",", ":"))
    with open(os.path.join(ZIEL, "portraits.bin"), "wb") as f:
        f.write(bytes(roh))
    print(f"{len(eintraege)} Fingerabdrücke ({len(roh) / 1024:.0f} KB), ohne Bild: {len(fehlt)} {fehlt[:20]}")


if __name__ == "__main__":
    main()
