"""
Porträt-Erkennung für den E&P Team-Analyzer (Referenz-Implementierung in Python).
Autor: FGSeRaser – https://github.com/FGSeRaser

Die Dart-Version in lib/erkennung/ rechnet exakt gleich. Hier wird sie zum
Erzeugen der Fingerabdrücke und zum Testen mit echten Screenshots benutzt.

Fingerabdruck eines Porträts:
  - Ausschnitt: Gesichtsbereich (AUSSCHNITT), damit Rahmen, Sterne und Level stören weniger
  - Mini-Bild: TW x TH Pixel RGB  (Form + Farbe)
  - Farb-Histogramm: 12 Farbtöne x 3 Sättigungen + 4 Graustufen = 40 Werte
"""
import math

TW, TH = 10, 12           # Mini-Bild
BINS = 40                 # Histogramm
AUSSCHNITT = (0.14, 0.10, 0.86, 0.72)   # links, oben, rechts, unten (Anteil vom Porträt)
# Seitenverhältnis des Porträts (Breite/Höhe) wie im Spiel: 166x225
PORTRAET_VERHAELTNIS = 166 / 225


def box_resize(px, w, h, x0, y0, x1, y1, tw, th):
    """Mittelt einen Bildbereich (Fließkomma-Koordinaten) auf tw x th Pixel.
    px: Liste/Bytes RGB(A) mit Zeilenlänge w*kanal; liefert Liste [r,g,b]*tw*th"""
    out = []
    sx = (x1 - x0) / tw
    sy = (y1 - y0) / th
    for j in range(th):
        ya = y0 + j * sy
        yb = ya + sy
        for i in range(tw):
            xa = x0 + i * sx
            xb = xa + sx
            r = g = b = n = 0
            # Stichprobe 4x4 im Feld – schnell und in Dart identisch
            for v in range(4):
                yy = int(ya + (v + 0.5) * (yb - ya) / 4)
                yy = min(max(yy, 0), h - 1)
                for u in range(4):
                    xx = int(xa + (u + 0.5) * (xb - xa) / 4)
                    xx = min(max(xx, 0), w - 1)
                    p = px[yy][xx]
                    r += p[0]
                    g += p[1]
                    b += p[2]
                    n += 1
            out.extend((r / n, g / n, b / n))
    return out


def histogramm(px, w, h, x0, y0, x1, y1):
    """HSV-Histogramm über Stichproben 24x24 im Bereich, normiert auf Summe 1."""
    hist = [0.0] * BINS
    n = 24
    for j in range(n):
        yy = min(max(int(y0 + (j + 0.5) * (y1 - y0) / n), 0), h - 1)
        for i in range(n):
            xx = min(max(int(x0 + (i + 0.5) * (x1 - x0) / n), 0), w - 1)
            r, g, b = px[yy][xx][:3]
            hist[bin_index(r, g, b)] += 1
    s = sum(hist) or 1
    return [v / s for v in hist]


def bin_index(r, g, b):
    mx = max(r, g, b)
    mn = min(r, g, b)
    d = mx - mn
    sat = 0 if mx == 0 else d / mx
    if sat < 0.18 or mx < 40:
        # Grau: 4 Helligkeitsstufen
        return 36 + min(int(mx / 64), 3)
    if mx == r:
        hue = ((g - b) / d) % 6
    elif mx == g:
        hue = (b - r) / d + 2
    else:
        hue = (r - g) / d + 4
    hb = min(int(hue * 2), 11)          # 12 Farbtöne
    sb = 0 if sat < 0.45 else (1 if sat < 0.75 else 2)
    return hb * 3 + sb


def normieren(vec):
    m = sum(vec) / len(vec)
    v = [x - m for x in vec]
    n = math.sqrt(sum(x * x for x in v)) or 1
    return [x / n for x in v]


def fingerabdruck(px, w, h, x0, y0, x1, y1):
    """Fingerabdruck für einen Porträt-Bereich (Koordinaten = ganzes Porträt)."""
    bw, bh = x1 - x0, y1 - y0
    ax0 = x0 + AUSSCHNITT[0] * bw
    ay0 = y0 + AUSSCHNITT[1] * bh
    ax1 = x0 + AUSSCHNITT[2] * bw
    ay1 = y0 + AUSSCHNITT[3] * bh
    mini = box_resize(px, w, h, ax0, ay0, ax1, ay1, TW, TH)
    hist = histogramm(px, w, h, ax0, ay0, ax1, ay1)
    return mini, hist


def aehnlichkeit(fa, fb):
    """0..1 – Kombination aus Bild-Korrelation und Histogramm-Schnittmenge."""
    na, ha = fa
    nb, hb = fb
    ncc = sum(x * y for x, y in zip(na, nb))           # -1..1 (beide schon normiert)
    hist = sum(min(x, y) for x, y in zip(ha, hb))      # 0..1
    return 0.6 * (ncc + 1) / 2 + 0.4 * hist


# ==========================================================================
# Screenshot-Erkennung
# ==========================================================================
SCHWELLE = 0.86      # Mindest-Ähnlichkeit, damit eine Zelle als Held gilt (echte Treffer ~0.93+)
VORAUSWAHL = 40      # so viele Kandidaten per Histogramm, dann genauer Vergleich


class Referenz:
    """Fingerabdrücke aller Helden (aus portraits.json/.bin)."""

    def __init__(self, meta, roh):
        self.ids = meta["ids"]
        self.trainer = set(meta.get("trainer", []))
        n = TW * TH * 3
        schritt = n + BINS
        self.minis, self.hists = [], []
        for k in range(len(self.ids)):
            off = k * schritt
            self.minis.append(normieren(list(roh[off:off + n])))
            self.hists.append([b / 255 for b in roh[off + n:off + schritt]])

    def vergleiche(self, fp, top=5, ausschluss=None):
        mini, hist = normieren(fp[0]), fp[1]
        hs = []
        for k, h in enumerate(self.hists):
            if ausschluss and self.ids[k] in ausschluss:
                continue
            hs.append((sum(min(a, b) for a, b in zip(hist, h)), k))
        hs.sort(reverse=True)
        erg = []
        for hsc, k in hs[:VORAUSWAHL]:
            ncc = sum(a * b for a, b in zip(mini, self.minis[k]))
            erg.append((0.6 * (ncc + 1) / 2 + 0.4 * hsc, self.ids[k]))
        erg.sort(reverse=True)
        return erg[:top]


class Raster:
    """Porträt-Raster: erstes Porträt bei (x0,y0), Größe pw x ph, Abstand dx/dy."""

    def __init__(self, x0, y0, pw, ph, dx, dy):
        self.x0, self.y0, self.pw, self.ph, self.dx, self.dy = x0, y0, pw, ph, dx, dy

    def zellen(self, w, h):
        out = []
        # x0/y0 ganz nach links/oben schieben, damit das Raster das ganze Bild abdeckt
        x0 = self.x0 - math.floor(self.x0 / self.dx) * self.dx
        y0 = self.y0 - math.floor(self.y0 / self.dy) * self.dy
        y = y0
        zeile = 0
        while y + self.ph <= h + 1:
            x = x0
            spalte = 0
            while x + self.pw <= w + 1:
                out.append((zeile, spalte, x, y, x + self.pw, y + self.ph))
                x += self.dx
                spalte += 1
            y += self.dy
            zeile += 1
        return out

    def __repr__(self):
        return f"Raster(x0={self.x0:.1f}, y0={self.y0:.1f}, pw={self.pw:.1f}, ph={self.ph:.1f}, dx={self.dx:.1f}, dy={self.dy:.1f})"


def grau(px, w, h):
    return [[(p[0] * 3 + p[1] * 6 + p[2]) / 10 for p in px[y]] for y in range(h)]


def periode(profil, lo, hi):
    """Stärkste Wiederholung (Autokorrelation) im Profil zwischen lo und hi."""
    n = len(profil)
    fenster = max(3, n // 40)
    glatt = []
    for i in range(n):
        a, b = max(0, i - fenster), min(n, i + fenster + 1)
        glatt.append(sum(profil[a:b]) / (b - a))
    d = [p - g for p, g in zip(profil, glatt)]
    best, best_l = -1e18, lo
    for lag in range(lo, min(hi, n - 1) + 1):
        s = sum(d[i] * d[i + lag] for i in range(n - lag)) / (n - lag)
        if s > best:
            best, best_l = s, lag
    return best_l


def raster_schaetzen(px, w, h):
    """Grobe Abstände der Karten über Kanten-Profile."""
    g = grau(px, w, h)
    y_a, y_b = int(h * 0.2), int(h * 0.9)
    spalten = [0.0] * w
    for y in range(y_a, y_b, 2):
        z = g[y]
        for x in range(w - 1):
            spalten[x] += abs(z[x + 1] - z[x])
    zeilen = [0.0] * h
    for y in range(h - 1):
        z, z2 = g[y], g[y + 1]
        zeilen[y] = sum(abs(z2[x] - z[x]) for x in range(0, w, 2))
    dx = periode(spalten, w // 9, w // 3)
    dy = periode(zeilen[y_a:y_b], h // 14, h // 3)
    return dx, dy


def bewerte(px, w, h, ref, raster, max_zellen=8):
    """Mittlere beste Ähnlichkeit der Zellen nahe der Bildmitte."""
    zellen = raster.zellen(w, h)
    if not zellen:
        return 0
    mitte = h / 2
    if max_zellen > 8:
        # Mittlere Reihe(n), aber alle Spalten – so fällt Abstands-Drift auf
        zellen.sort(key=lambda z: (abs((z[3] + z[5]) / 2 - mitte), z[1]))
    else:
        zellen.sort(key=lambda z: abs((z[3] + z[5]) / 2 - mitte))
    werte = []
    for z in zellen[:max_zellen]:
        fp = fingerabdruck(px, w, h, *z[2:])
        werte.append(ref.vergleiche(fp, top=1)[0][0])
    werte.sort(reverse=True)
    oben = werte[:max(1, len(werte) * 3 // 4)]
    return sum(oben) / len(oben)


def raster_suchen(px, w, h, ref, verhaeltnis=PORTRAET_VERHAELTNIS):
    dx, dy = raster_schaetzen(px, w, h)
    best = (0, None)
    # 1) Versatz grob suchen
    for fx in [0.86, 0.92]:
        pw = dx * fx
        ph = pw / verhaeltnis
        for i in range(10):
            for j in range(10):
                r = Raster(dx * i / 10, dy * j / 10, pw, ph, dx, dy)
                s = bewerte(px, w, h, ref, r, 6)
                if s > best[0]:
                    best = (s, r)
    # 2) fein nachjustieren
    s0, r0 = best
    schritte = [dx * 0.04, dx * 0.02, dx * 0.01]
    for st in schritte:
        verbessert = True
        while verbessert:
            verbessert = False
            for ddx0, ddy0, dpw, ddx, ddy in [(st, 0, 0, 0, 0), (-st, 0, 0, 0, 0), (0, st, 0, 0, 0),
                                              (0, -st, 0, 0, 0), (0, 0, st, 0, 0), (0, 0, -st, 0, 0),
                                              (0, 0, 0, st / 2, 0), (0, 0, 0, -st / 2, 0),
                                              (0, 0, 0, 0, st / 2), (0, 0, 0, 0, -st / 2)]:
                pw = r0.pw + dpw
                r = Raster(r0.x0 + ddx0 - dpw / 2, r0.y0 + ddy0, pw, pw / verhaeltnis, r0.dx + ddx, r0.dy + ddy)
                # Abstände über ALLE Zellen bewerten, sonst merkt man den Drift am Rand nicht
                s = bewerte(px, w, h, ref, r, 8 if not (ddx or ddy) else 16)
                if ddx or ddy:
                    s_alt = bewerte(px, w, h, ref, r0, 16)
                    if s > s_alt + 1e-4:
                        s0, r0, verbessert = bewerte(px, w, h, ref, r, 8), r, True
                elif s > s0 + 1e-4:
                    s0, r0, verbessert = s, r, True
    return r0, s0, (dx, dy)


def erkenne(px, w, h, ref, raster, schwelle=SCHWELLE):
    out = []
    for z in raster.zellen(w, h):
        fp = fingerabdruck(px, w, h, *z[2:])
        kand = ref.vergleiche(fp, top=5)
        if kand[0][0] >= schwelle:
            out.append((z, kand))
    return out
