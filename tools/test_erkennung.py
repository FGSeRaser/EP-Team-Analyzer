#!/usr/bin/env python3
"""
Testet die Screenshot-Erkennung.
Autor: FGSeRaser – https://github.com/FGSeRaser

  python3 tools/test_erkennung.py <heroplan-repo>              -> nachgebauter Screenshot
  python3 tools/test_erkennung.py <heroplan-repo> bild.png     -> echter Screenshot
"""
import json
import os
import random
import sys
import time

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import erkennung as E  # noqa: E402
from build_portraits import Pixel  # noqa: E402

HIER = os.path.dirname(os.path.abspath(__file__))
DATEN = os.path.join(HIER, "..", "assets", "data")
ARBEITSBREITE = 540
FARBEN = {"rot": (200, 50, 40), "blau": (40, 110, 210), "gruen": (50, 160, 60),
          "gelb": (220, 190, 40), "lila": (140, 50, 170)}


def stern(d, cx, cy, r):
    import math
    pts = []
    for k in range(10):
        rr = r if k % 2 == 0 else r * 0.45
        a = -math.pi / 2 + k * math.pi / 5
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, fill=(255, 205, 40), outline=(120, 70, 0))


def nachbau(hp, helden, spalten=5, seed=1):
    random.seed(seed)
    W, H = 1080, 2340
    bild = Image.new("RGB", (W, H), (35, 28, 22))
    d = ImageDraw.Draw(bild)
    # Kopfbereich mit Bedienelementen
    d.rectangle((0, 0, W, 330), fill=(70, 50, 30))
    for _ in range(12):
        x, y = random.randint(0, W - 200), random.randint(20, 300)
        d.rectangle((x, y, x + random.randint(60, 200), y + random.randint(30, 80)),
                    fill=tuple(random.randint(60, 220) for _ in range(3)))
    d.rectangle((0, H - 200, W, H), fill=(60, 45, 30))
    rand, abstand = 30, 14
    kw = (W - 2 * rand - (spalten - 1) * abstand) / spalten
    pw = kw - 16
    ph = pw * 225 / 166
    kh = ph + 16 + 40
    wahr = []
    y = 360
    k = 0
    while y + kh < H - 210:
        for s in range(spalten):
            h = helden[k % len(helden)]
            k += 1
            x = rand + s * (kw + abstand)
            d.rounded_rectangle((x, y, x + kw, y + kh), 10, fill=FARBEN.get(h["e"], (120, 120, 120)))
            p = Image.open(os.path.join(hp, "imgs", "hero_icon", h["id"] + ".webp")).convert("RGBA")
            p = p.resize((int(pw), int(ph)))
            hg = Image.new("RGBA", p.size, (25, 25, 25, 255))
            hg.alpha_composite(p)
            bild.paste(hg.convert("RGB"), (int(x + 8), int(y + 8)))
            # Sterne unten über dem Porträt, Level-Kreis links unten
            for t in range(h["s"]):
                stern(d, x + kw / 2 + (t - (h["s"] - 1) / 2) * 30, y + 8 + ph - 8, 14)
            d.ellipse((x + 4, y + kh - 50, x + 50, y + kh - 4), fill=(20, 20, 20), outline=(230, 230, 230), width=3)
            d.text((x + 16, y + kh - 34), str(random.randint(1, 80)), fill=(255, 255, 255))
            wahr.append(h["id"])
        y += kh + abstand
    bild = bild.filter(ImageFilter.GaussianBlur(0.6))
    pfad = os.path.join("/tmp", f"nachbau_{spalten}.jpg")
    bild.save(pfad, quality=72)
    return pfad, wahr


def lade_ref():
    meta = json.load(open(os.path.join(DATEN, "portraits.json")))
    roh = open(os.path.join(DATEN, "portraits.bin"), "rb").read()
    return E.Referenz(meta, roh)


def pruefe(pfad, ref, wahr=None):
    im = Image.open(pfad).convert("RGB")
    f = ARBEITSBREITE / im.width
    im = im.resize((ARBEITSBREITE, round(im.height * f)), Image.BILINEAR)
    px = Pixel(im)
    t = time.time()
    raster, score, (dx, dy) = E.raster_suchen(px, px.w, px.h, ref)
    print(f"Abstand geschätzt dx={dx} dy={dy}; gefunden {raster} Güte {score:.3f} ({time.time() - t:.1f}s)")
    erg = E.erkenne(px, px.w, px.h, ref, raster)
    print(f"{len(erg)} Helden-Zellen erkannt")
    if wahr:
        treffer = sum(1 for (z, kand), w in zip(erg, wahr) if kand[0][1] == w)
        top3 = sum(1 for (z, kand), w in zip(erg, wahr) if w in [k[1] for k in kand[:3]])
        print(f"Platz 1 richtig: {treffer}/{len(wahr)}   unter Top-3: {top3}/{len(wahr)}")
        for (z, kand), w in list(zip(erg, wahr)):
            if kand[0][1] != w:
                print("  falsch:", w, "->", [(k[1], round(k[0], 3)) for k in kand[:3]])
    elif len(sys.argv) > 2:
        for z, kand in erg:
            print(z[:2], [(k[1], round(k[0], 3)) for k in kand[:3]])
    return raster, erg


def main():
    hp = sys.argv[1]
    ref = lade_ref()
    if len(sys.argv) > 2:
        pruefe(sys.argv[2], ref)
        return
    helden = [h for h in json.load(open(os.path.join(DATEN, "helden.json")))["helden"]
              if not h.get("neu") and os.path.exists(os.path.join(hp, "imgs", "hero_icon", h["id"] + ".webp"))]
    random.seed(7)
    random.shuffle(helden)
    for spalten in (5, 4):
        pfad, wahr = nachbau(hp, helden[spalten * 40:], spalten)
        print(f"\n=== Nachbau mit {spalten} Spalten: {pfad} ({len(wahr)} Helden)")
        pruefe(pfad, ref, wahr)

    # Echte Screenshots aus dem Spiel (Namen = Erwartung, Kostüm egal)
    ordner = os.path.join(HIER, "testbilder")
    erwartet = json.load(open(os.path.join(ordner, "erwartet.json"), encoding="utf-8"))
    namen = {h["id"]: h["n"] for h in json.load(open(os.path.join(DATEN, "helden.json")))["helden"]}
    for datei, soll in erwartet.items():
        print(f"\n=== Echter Screenshot {datei}")
        _, erg = pruefe(os.path.join(ordner, datei), ref)
        ist = [namen.get(k[0][1], k[0][1]) for _, k in erg]
        richtig = sum(1 for a, b in zip(ist, soll) if a == b)
        print(f"Richtig: {richtig}/{len(soll)}" + ("" if ist == soll else f"  erkannt: {ist}"))


if __name__ == "__main__":
    main()
