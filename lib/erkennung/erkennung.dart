// E&P Team-Analyzer – Porträt-Erkennung in Screenshots
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Exakt dieselbe Rechnung wie tools/erkennung.py (dort getestet).
// Läuft ohne Flutter-Abhängigkeiten, damit es in einem Isolate rechnen kann.

import 'dart:math' as math;
import 'dart:typed_data';

const int tw = 10, th = 12, bins = 40;
const List<double> ausschnitt = [0.14, 0.10, 0.86, 0.72];
const double portraetVerhaeltnis = 166 / 225;
const double schwelle = 0.86;
const int vorauswahl = 40;
const int arbeitsbreite = 540;

/// Bild als RGBA-Bytes
class Bild {
  final Uint8List rgba;
  final int w, h;
  const Bild(this.rgba, this.w, this.h);

  int r(int x, int y) => rgba[(y * w + x) * 4];
  int g(int x, int y) => rgba[(y * w + x) * 4 + 1];
  int b(int x, int y) => rgba[(y * w + x) * 4 + 2];
}

class Fingerabdruck {
  final List<double> mini; // TW*TH*3 RGB-Mittelwerte
  final List<double> hist; // BINS, Summe 1
  const Fingerabdruck(this.mini, this.hist);
}

int _clamp(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

List<double> _boxResize(Bild p, double x0, double y0, double x1, double y1, int ow, int oh) {
  final out = <double>[];
  final sx = (x1 - x0) / ow;
  final sy = (y1 - y0) / oh;
  for (var j = 0; j < oh; j++) {
    final ya = y0 + j * sy;
    final yb = ya + sy;
    for (var i = 0; i < ow; i++) {
      final xa = x0 + i * sx;
      final xb = xa + sx;
      var r = 0, g = 0, b = 0, n = 0;
      for (var v = 0; v < 4; v++) {
        final yy = _clamp((ya + (v + 0.5) * (yb - ya) / 4).toInt(), 0, p.h - 1);
        for (var u = 0; u < 4; u++) {
          final xx = _clamp((xa + (u + 0.5) * (xb - xa) / 4).toInt(), 0, p.w - 1);
          final o = (yy * p.w + xx) * 4;
          r += p.rgba[o];
          g += p.rgba[o + 1];
          b += p.rgba[o + 2];
          n++;
        }
      }
      out
        ..add(r / n)
        ..add(g / n)
        ..add(b / n);
    }
  }
  return out;
}

int binIndex(int r, int g, int b) {
  final mx = math.max(r, math.max(g, b));
  final mn = math.min(r, math.min(g, b));
  final d = mx - mn;
  final sat = mx == 0 ? 0.0 : d / mx;
  if (sat < 0.18 || mx < 40) {
    return 36 + math.min(mx ~/ 64, 3);
  }
  double hue;
  if (mx == r) {
    hue = ((g - b) / d) % 6;
  } else if (mx == g) {
    hue = (b - r) / d + 2;
  } else {
    hue = (r - g) / d + 4;
  }
  final hb = math.min((hue * 2).toInt(), 11);
  final sb = sat < 0.45 ? 0 : (sat < 0.75 ? 1 : 2);
  return hb * 3 + sb;
}

List<double> _histogramm(Bild p, double x0, double y0, double x1, double y1) {
  final hist = List<double>.filled(bins, 0);
  const n = 24;
  for (var j = 0; j < n; j++) {
    final yy = _clamp((y0 + (j + 0.5) * (y1 - y0) / n).toInt(), 0, p.h - 1);
    for (var i = 0; i < n; i++) {
      final xx = _clamp((x0 + (i + 0.5) * (x1 - x0) / n).toInt(), 0, p.w - 1);
      final o = (yy * p.w + xx) * 4;
      hist[binIndex(p.rgba[o], p.rgba[o + 1], p.rgba[o + 2])] += 1;
    }
  }
  final s = hist.fold<double>(0, (a, b) => a + b);
  return [for (final v in hist) v / (s == 0 ? 1 : s)];
}

List<double> normieren(List<double> vec) {
  final m = vec.fold<double>(0, (a, b) => a + b) / vec.length;
  final v = [for (final x in vec) x - m];
  var n = math.sqrt(v.fold<double>(0, (a, b) => a + b * b));
  if (n == 0) n = 1;
  return [for (final x in v) x / n];
}

Fingerabdruck fingerabdruck(Bild p, double x0, double y0, double x1, double y1) {
  final bw = x1 - x0, bh = y1 - y0;
  final ax0 = x0 + ausschnitt[0] * bw;
  final ay0 = y0 + ausschnitt[1] * bh;
  final ax1 = x0 + ausschnitt[2] * bw;
  final ay1 = y0 + ausschnitt[3] * bh;
  return Fingerabdruck(_boxResize(p, ax0, ay0, ax1, ay1, tw, th), _histogramm(p, ax0, ay0, ax1, ay1));
}

class Kandidat {
  final String id;
  final double wert;
  const Kandidat(this.id, this.wert);
}

/// Fingerabdrücke aller Helden
class Referenz {
  final List<String> ids;
  final Set<String> trainer;
  final List<Float64List> _minis = [];
  final List<Float64List> _hists = [];

  Referenz(this.ids, this.trainer, Uint8List roh) {
    const n = tw * th * 3;
    const schritt = n + bins;
    for (var k = 0; k < ids.length; k++) {
      final off = k * schritt;
      final mini = normieren([for (var i = 0; i < n; i++) roh[off + i].toDouble()]);
      _minis.add(Float64List.fromList(mini));
      _hists.add(Float64List.fromList([for (var i = 0; i < bins; i++) roh[off + n + i] / 255]));
    }
  }

  List<Kandidat> vergleiche(Fingerabdruck fp, {int top = 5, Set<String>? erlaubt}) {
    final mini = normieren(fp.mini);
    final hist = fp.hist;
    final hs = <MapEntry<double, int>>[];
    for (var k = 0; k < _hists.length; k++) {
      if (erlaubt != null && !erlaubt.contains(ids[k])) continue;
      final h = _hists[k];
      var s = 0.0;
      for (var i = 0; i < bins; i++) {
        s += hist[i] < h[i] ? hist[i] : h[i];
      }
      hs.add(MapEntry(s, k));
    }
    hs.sort((a, b) => b.key.compareTo(a.key));
    final erg = <Kandidat>[];
    for (final e in hs.take(vorauswahl)) {
      final m = _minis[e.value];
      var ncc = 0.0;
      for (var i = 0; i < m.length; i++) {
        ncc += mini[i] * m[i];
      }
      erg.add(Kandidat(ids[e.value], 0.6 * (ncc + 1) / 2 + 0.4 * e.key));
    }
    erg.sort((a, b) => b.wert.compareTo(a.wert));
    return erg.take(top).toList();
  }
}

/// Raster: erstes Porträt bei (x0,y0), Größe pw x ph, Abstand dx/dy (in Arbeitsbild-Pixeln)
class Raster {
  final double x0, y0, pw, ph, dx, dy;
  const Raster(this.x0, this.y0, this.pw, this.ph, this.dx, this.dy);

  Raster kopie({double? x0, double? y0, double? pw, double? dx, double? dy}) {
    final neuPw = pw ?? this.pw;
    return Raster(x0 ?? this.x0, y0 ?? this.y0, neuPw, neuPw / portraetVerhaeltnis, dx ?? this.dx, dy ?? this.dy);
  }

  Raster skaliert(double f) => Raster(x0 * f, y0 * f, pw * f, ph * f, dx * f, dy * f);

  List<Zelle> zellen(int w, int h) {
    final out = <Zelle>[];
    if (dx <= 1 || dy <= 1) return out;
    final sx = x0 - (x0 / dx).floorToDouble() * dx;
    final sy = y0 - (y0 / dy).floorToDouble() * dy;
    var y = sy;
    var zeile = 0;
    while (y + ph <= h + 1) {
      var x = sx;
      var spalte = 0;
      while (x + pw <= w + 1) {
        out.add(Zelle(zeile, spalte, x, y, x + pw, y + ph));
        x += dx;
        spalte++;
      }
      y += dy;
      zeile++;
    }
    return out;
  }
}

class Zelle {
  final int zeile, spalte;
  final double x0, y0, x1, y1;
  const Zelle(this.zeile, this.spalte, this.x0, this.y0, this.x1, this.y1);
}

class Treffer {
  final Zelle zelle;
  final List<Kandidat> kandidaten;
  const Treffer(this.zelle, this.kandidaten);
}

int periode(List<double> profil, int lo, int hi) {
  final n = profil.length;
  final fenster = math.max(3, n ~/ 40);
  final d = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final a = math.max(0, i - fenster), b = math.min(n, i + fenster + 1);
    var s = 0.0;
    for (var k = a; k < b; k++) {
      s += profil[k];
    }
    d[i] = profil[i] - s / (b - a);
  }
  var best = -1e18;
  var bestL = lo;
  for (var lag = lo; lag <= math.min(hi, n - 1); lag++) {
    var s = 0.0;
    for (var i = 0; i < n - lag; i++) {
      s += d[i] * d[i + lag];
    }
    s /= (n - lag);
    if (s > best) {
      best = s;
      bestL = lag;
    }
  }
  return bestL;
}

/// Grobe Kartenabstände über Kanten-Profile
(int, int) rasterSchaetzen(Bild p) {
  final w = p.w, h = p.h;
  double grau(int x, int y) {
    final o = (y * w + x) * 4;
    return (p.rgba[o] * 3 + p.rgba[o + 1] * 6 + p.rgba[o + 2]) / 10;
  }

  final ya = (h * 0.2).toInt(), yb = (h * 0.9).toInt();
  final spalten = List<double>.filled(w, 0);
  for (var y = ya; y < yb; y += 2) {
    for (var x = 0; x < w - 1; x++) {
      spalten[x] += (grau(x + 1, y) - grau(x, y)).abs();
    }
  }
  final zeilen = List<double>.filled(h, 0);
  for (var y = 0; y < h - 1; y++) {
    var s = 0.0;
    for (var x = 0; x < w; x += 2) {
      s += (grau(x, y + 1) - grau(x, y)).abs();
    }
    zeilen[y] = s;
  }
  final dx = periode(spalten, w ~/ 9, w ~/ 3);
  final dy = periode(zeilen.sublist(ya, yb), h ~/ 14, h ~/ 3);
  return (dx, dy);
}

double bewerte(Bild p, Referenz ref, Raster r, [int maxZellen = 8]) {
  final zellen = r.zellen(p.w, p.h);
  if (zellen.isEmpty) return 0;
  final mitte = p.h / 2;
  zellen.sort((a, b) {
    final c = ((a.y0 + a.y1) / 2 - mitte).abs().compareTo(((b.y0 + b.y1) / 2 - mitte).abs());
    // Bei vielen Zellen: mittlere Reihe(n), aber alle Spalten – so fällt Abstands-Drift auf
    return (c != 0 || maxZellen <= 8) ? c : a.spalte.compareTo(b.spalte);
  });
  final werte = <double>[];
  for (final z in zellen.take(maxZellen)) {
    final fp = fingerabdruck(p, z.x0, z.y0, z.x1, z.y1);
    werte.add(ref.vergleiche(fp, top: 1).first.wert);
  }
  werte.sort((a, b) => b.compareTo(a));
  final anzahl = math.max(1, werte.length * 3 ~/ 4);
  return werte.take(anzahl).fold<double>(0, (a, b) => a + b) / anzahl;
}

/// Sucht das Raster automatisch
Raster rasterSuchen(Bild p, Referenz ref) {
  final (dxI, dyI) = rasterSchaetzen(p);
  final dx = dxI.toDouble(), dy = dyI.toDouble();
  var bestS = 0.0;
  Raster? best;
  for (final fx in [0.86, 0.92]) {
    final pw = dx * fx;
    final ph = pw / portraetVerhaeltnis;
    for (var i = 0; i < 10; i++) {
      for (var j = 0; j < 10; j++) {
        final r = Raster(dx * i / 10, dy * j / 10, pw, ph, dx, dy);
        final s = bewerte(p, ref, r, 6);
        if (s > bestS) {
          bestS = s;
          best = r;
        }
      }
    }
  }
  var r0 = best ?? Raster(0, 0, dx * 0.9, dx * 0.9 / portraetVerhaeltnis, dx, dy);
  var s0 = bestS;
  for (final st in [dx * 0.04, dx * 0.02, dx * 0.01]) {
    var verbessert = true;
    while (verbessert) {
      verbessert = false;
      for (final d in const [
        [1, 0, 0, 0, 0],
        [-1, 0, 0, 0, 0],
        [0, 1, 0, 0, 0],
        [0, -1, 0, 0, 0],
        [0, 0, 1, 0, 0],
        [0, 0, -1, 0, 0],
        [0, 0, 0, 1, 0],
        [0, 0, 0, -1, 0],
        [0, 0, 0, 0, 1],
        [0, 0, 0, 0, -1],
      ]) {
        final dpw = d[2] * st;
        final ddx = d[3] * st / 2, ddy = d[4] * st / 2;
        final pw = r0.pw + dpw;
        final r = Raster(
            r0.x0 + d[0] * st - dpw / 2, r0.y0 + d[1] * st, pw, pw / portraetVerhaeltnis, r0.dx + ddx, r0.dy + ddy);
        if (ddx != 0 || ddy != 0) {
          // Abstände über alle Spalten bewerten, sonst merkt man den Drift am Rand nicht
          if (bewerte(p, ref, r, 16) > bewerte(p, ref, r0, 16) + 1e-4) {
            s0 = bewerte(p, ref, r, 8);
            r0 = r;
            verbessert = true;
          }
        } else {
          final s = bewerte(p, ref, r, 8);
          if (s > s0 + 1e-4) {
            s0 = s;
            r0 = r;
            verbessert = true;
          }
        }
      }
    }
  }
  return r0;
}

List<Treffer> erkenne(Bild p, Referenz ref, Raster r, {double minWert = schwelle, Set<String>? erlaubt}) {
  final out = <Treffer>[];
  for (final z in r.zellen(p.w, p.h)) {
    final fp = fingerabdruck(p, z.x0, z.y0, z.x1, z.y1);
    final kand = ref.vergleiche(fp, top: 15, erlaubt: erlaubt);
    if (kand.isNotEmpty && kand.first.wert >= minWert) out.add(Treffer(z, kand));
  }
  return out;
}

// --------------------------------------------------------------------------
// Isolate-Einstieg: alles in einem Rutsch rechnen
// --------------------------------------------------------------------------
class ErkennungsAuftrag {
  final Uint8List rgba;
  final int w, h;
  final List<String> ids;
  final List<String> trainer;
  final Uint8List refRoh;

  /// Wenn gesetzt: dieses Raster benutzen statt automatisch suchen
  final Raster? raster;
  const ErkennungsAuftrag(this.rgba, this.w, this.h, this.ids, this.trainer, this.refRoh, this.raster);
}

class ErkennungsErgebnis {
  final Raster raster;
  final List<Treffer> treffer;
  const ErkennungsErgebnis(this.raster, this.treffer);
}

ErkennungsErgebnis erkennungAusfuehren(ErkennungsAuftrag a) {
  final ref = Referenz(a.ids, a.trainer.toSet(), a.refRoh);
  final bild = Bild(a.rgba, a.w, a.h);
  final raster = a.raster ?? rasterSuchen(bild, ref);
  return ErkennungsErgebnis(raster, erkenne(bild, ref, raster));
}
