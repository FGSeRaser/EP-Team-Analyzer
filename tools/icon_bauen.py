#!/usr/bin/env python3
"""
Zeichnet das App-Icon des E&P Team-Analyzer (eigenes Motiv).
Autor: FGSeRaser – https://github.com/FGSeRaser

Erzeugt:
  assets/icon/icon.png                 (1024 px, für die App selbst)
  android-icon/mipmap-*/ic_launcher.png und ic_launcher_round.png
  android-icon/mipmap-*/ic_launcher_foreground.png (adaptives Icon, Android 8+)
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HIER = os.path.dirname(os.path.abspath(__file__))
WURZEL = os.path.join(HIER, "..")
S = 4  # Supersampling

GOLD_HELL = (255, 214, 102)
GOLD = (232, 168, 36)
GOLD_DUNKEL = (150, 92, 10)
ELEMENTE = [(229, 57, 53), (67, 160, 71), (30, 136, 229), (253, 216, 53), (142, 36, 170)]


def verlauf(gr, oben, unten):
    bild = Image.new("RGBA", (gr, gr))
    d = ImageDraw.Draw(bild)
    for y in range(gr):
        f = y / (gr - 1)
        d.line([(0, y), (gr, y)], fill=tuple(int(oben[i] + (unten[i] - oben[i]) * f) for i in range(3)) + (255,))
    return bild


def schild_punkte(cx, cy, b, h):
    pts = []
    oben = cy - h * 0.5
    pts += [(cx - b / 2, oben + h * 0.08), (cx - b * 0.25, oben), (cx, oben + h * 0.05),
            (cx + b * 0.25, oben), (cx + b / 2, oben + h * 0.08)]
    for i in range(1, 21):  # rechte Kurve nach unten zur Spitze
        t = i / 20
        x = cx + b / 2 * (1 - t ** 1.8)
        y = oben + h * 0.08 + (h * 0.92) * (t ** 0.9)
        pts.append((x, y))
    for i in range(19, 0, -1):
        t = i / 20
        x = cx - b / 2 * (1 - t ** 1.8)
        y = oben + h * 0.08 + (h * 0.92) * (t ** 0.9)
        pts.append((x, y))
    return pts


def motiv(gr, mit_hintergrund=True):
    G = gr * S
    if mit_hintergrund:
        bild = verlauf(G, (28, 44, 92), (10, 16, 40))
        maske = Image.new("L", (G, G), 0)
        ImageDraw.Draw(maske).rounded_rectangle((0, 0, G - 1, G - 1), radius=int(G * 0.22), fill=255)
        hg = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        hg.paste(bild, (0, 0), maske)
        bild = hg
        # weicher Lichtschein hinter dem Schild
        glanz = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        ImageDraw.Draw(glanz).ellipse((G * 0.15, G * 0.12, G * 0.85, G * 0.82), fill=(255, 190, 60, 70))
        bild.alpha_composite(glanz.filter(ImageFilter.GaussianBlur(G * 0.08)))
        massstab = 1.0
    else:
        bild = Image.new("RGBA", (G, G), (0, 0, 0, 0))
        massstab = 0.66  # adaptives Icon: Motiv muss in die Mitte (Sicherheitszone)

    d = ImageDraw.Draw(bild)
    cx, cy = G / 2, G * 0.53
    b, h = G * 0.56 * massstab, G * 0.66 * massstab

    # Schatten
    schatten = Image.new("RGBA", (G, G), (0, 0, 0, 0))
    ImageDraw.Draw(schatten).polygon(schild_punkte(cx, cy + G * 0.02, b, h), fill=(0, 0, 0, 140))
    bild.alpha_composite(schatten.filter(ImageFilter.GaussianBlur(G * 0.02)))

    # Schild: goldener Rand, dunkles Innenfeld
    d.polygon(schild_punkte(cx, cy, b, h), fill=GOLD_DUNKEL)
    d.polygon(schild_punkte(cx, cy - G * 0.004, b * 0.97, h * 0.97), fill=GOLD)
    d.polygon(schild_punkte(cx, cy + G * 0.006, b * 0.80, h * 0.82), fill=(20, 30, 70))

    # Gekreuzte Schwerter
    def schwert(winkel):
        laenge = h * 0.58
        rad = math.radians(winkel)
        dx, dy = math.sin(rad), -math.cos(rad)
        nx, ny = -dy, dx
        mx, my = cx, cy - h * 0.03
        spitze = (mx + dx * laenge / 2, my + dy * laenge / 2)
        basis = (mx - dx * laenge * 0.28, my - dy * laenge * 0.28)
        br = G * 0.036 * massstab
        d.polygon([(basis[0] + nx * br, basis[1] + ny * br), (spitze[0], spitze[1]),
                   (basis[0] - nx * br, basis[1] - ny * br)], fill=(225, 232, 245))
        d.line([basis, spitze], fill=(160, 172, 196), width=max(1, int(G * 0.006 * massstab)))
        q = G * 0.075 * massstab  # Parierstange
        d.line([(basis[0] + nx * q, basis[1] + ny * q), (basis[0] - nx * q, basis[1] - ny * q)],
               fill=GOLD_HELL, width=int(G * 0.022 * massstab))
        griff = (basis[0] - dx * laenge * 0.2, basis[1] - dy * laenge * 0.2)
        d.line([basis, griff], fill=(110, 60, 20), width=int(G * 0.03 * massstab))
        r = G * 0.022 * massstab
        d.ellipse((griff[0] - r, griff[1] - r, griff[0] + r, griff[1] + r), fill=GOLD_HELL)

    schwert(-38)
    schwert(38)

    # Fünf Element-Edelsteine im Bogen über dem Schild
    bogen_r = h * 0.62
    for i, farbe in enumerate(ELEMENTE):
        w = math.radians(-50 + i * 25)
        x = cx + bogen_r * math.sin(w)
        y = cy - h * 0.06 - bogen_r * math.cos(w) * 0.62
        r = G * 0.048 * massstab
        d.ellipse((x - r * 1.18, y - r * 1.18, x + r * 1.18, y + r * 1.18), fill=GOLD_DUNKEL)
        d.ellipse((x - r, y - r, x + r, y + r), fill=farbe)
        d.ellipse((x - r * 0.45, y - r * 0.6, x - r * 0.05, y - r * 0.2), fill=(255, 255, 255, 170))

    return bild.resize((gr, gr), Image.LANCZOS)


def main():
    motiv(1024).save(os.path.join(WURZEL, "assets", "icon", "icon.png"))
    groessen = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for name, px in groessen.items():
        ordner = os.path.join(WURZEL, "android-icon", f"mipmap-{name}")
        os.makedirs(ordner, exist_ok=True)
        icon = motiv(px)
        icon.save(os.path.join(ordner, "ic_launcher.png"))
        rund = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        maske = Image.new("L", (px * 4, px * 4), 0)
        ImageDraw.Draw(maske).ellipse((0, 0, px * 4 - 1, px * 4 - 1), fill=255)
        rund.paste(motiv(px), (0, 0), maske.resize((px, px), Image.LANCZOS))
        rund.save(os.path.join(ordner, "ic_launcher_round.png"))
        vorder = int(px * 108 / 48)  # adaptives Icon: 108 dp
        motiv(vorder, mit_hintergrund=False).save(os.path.join(ordner, "ic_launcher_foreground.png"))
    print("Icon erzeugt.")


if __name__ == "__main__":
    main()
