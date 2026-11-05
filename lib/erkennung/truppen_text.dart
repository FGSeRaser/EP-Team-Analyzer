// E&P Team-Analyzer – Truppen aus einem Screenshot lesen (Kaserne / Truppen-Ansicht)
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Ablauf: Texterkennung liefert Zeilen -> bekannte Truppennamen (englisch) oder
// Stichworte (Mana, Krit, Zyklop, Ninja …) finden -> Level in der Nähe suchen ->
// Farbe aus dem Namen, sonst aus den Bildpixeln rund um den Namen.
// Das Ergebnis ist ein Vorschlag – der Nutzer prüft ihn vor dem Speichern.

import '../daten/truppen.dart';
import '../daten/namen_suche.dart';
import 'erkennung.dart';
import 'kartentext.dart';

class TruppenTreffer {
  String farbe; // rot, blau, gruen, gelb, lila oder '' wenn unbekannt
  String typ; // mana, krit, magie, styx, ninja, leg
  String? legName;
  int level;
  final String gelesen; // erkannter Text (zur Kontrolle)
  bool uebernehmen = true;
  TruppenTreffer({required this.farbe, required this.typ, this.legName, this.level = 1, required this.gelesen});
}

/// Englische Truppennamen aus dem Spiel (Quelle: empuzzled.com)
const Map<String, (String, String)> truppenNamen = {
  // Mana-Truppen
  'Ravager Warriors': ('blau', 'mana'),
  'Rebel Infiltrators': ('gruen', 'mana'),
  'Barbaric Assassins': ('rot', 'mana'),
  'Monastic Battlemages': ('gelb', 'mana'),
  'Mystic Mages': ('lila', 'mana'),
  // Krit-Truppen
  'Imperial Knight Lords': ('blau', 'krit'),
  'Deepwood Elder Ents': ('gruen', 'krit'),
  'Barbaric Alpha Minotaurs': ('rot', 'krit'),
  'Exalted War Constructs': ('gelb', 'krit'),
  'Reanimated Master Knights': ('lila', 'krit'),
};

const _farbWoerter = {
  'rot': ['feuer', 'fire', 'rot', 'red'],
  'blau': ['eis', 'ice', 'blau', 'blue'],
  'gruen': ['natur', 'nature', 'grün', 'gruen', 'green'],
  'gelb': ['heilig', 'holy', 'gelb', 'yellow'],
  'lila': ['finster', 'dark', 'lila', 'purple'],
};

/// Alle bekannten Namen: (normierter Name, Farbe, Typ, legName)
List<(String, String, String, String?)> _bekannteNamen(TruppenWissen w) {
  final out = <(String, String, String, String?)>[];
  truppenNamen.forEach((name, v) => out.add((normName(name), v.$1, v.$2, null)));
  for (final e in w.episch) {
    e.namen.forEach((farbe, name) => out.add((normName(name), farbe, e.id, null)));
  }
  for (final l in w.legendaer) {
    out.add((normName(l.name), '', 'leg', l.name));
  }
  return out;
}

/// Name -> Treffer (exakt, Teilstring oder mit kleinem Tippfehler)
(String, String, String?)? truppeAusName(String text, TruppenWissen w) {
  final n = normName(text);
  if (n.length < 4) return null;
  (String, String, String?)? bester;
  var besterAbstand = 99;
  for (final (name, farbe, typ, leg) in _bekannteNamen(w)) {
    if (n == name || (n.length >= 8 && (n.contains(name) || name.contains(n)))) return (farbe, typ, leg);
    // Plural/Singular und OCR-Fehler: Levenshtein relativ zur Länge
    final d = levenshtein(n, name);
    final grenze = (name.length / 6).floor().clamp(1, 3);
    if (d <= grenze && d < besterAbstand) {
      besterAbstand = d;
      bester = (farbe, typ, leg);
    }
  }
  if (bester != null) return bester;
  // Stichworte (deutscher Client oder unbekannter Name) – Werte-Zeilen wie „Mana +5 %“ überspringen
  if (text.contains('%') || RegExp(r'[+\-]\s*\d').hasMatch(text)) return null;
  final klein = text.toLowerCase();
  String? typ;
  if (RegExp(r'\bmana').hasMatch(klein)) {
    typ = 'mana';
  } else if (RegExp(r'\b(krit|crit)').hasMatch(klein)) {
    typ = 'krit';
  } else if (RegExp(r'(zyklop|cyclop)').hasMatch(klein)) {
    typ = 'styx';
  } else if (klein.contains('ninja')) {
    typ = 'ninja';
  } else if (RegExp(r'(wizard|zauberer|magier)').hasMatch(klein)) {
    typ = 'magie';
  }
  if (typ == null) return null;
  var farbe = '';
  _farbWoerter.forEach((f, woerter) {
    if (woerter.any((x) => RegExp('\\b$x').hasMatch(klein))) farbe = f;
  });
  return (farbe, typ, null);
}

final _levelMuster = [
  RegExp(r'(?:lvl|lv|level|stufe|st)\.?\s*:?\s*(\d{1,2})', caseSensitive: false),
  RegExp(r'\b(\d{1,2})\s*/\s*(?:10|15|22|30|40)\b'),
];

int? levelAus(String text) {
  for (final m in _levelMuster) {
    final x = m.firstMatch(text);
    if (x != null) {
      final v = int.tryParse(x.group(1)!);
      if (v != null && v >= 1 && v <= 40) return v;
    }
  }
  return null;
}

/// Hauptfarbe (Element) in einem Bildbereich – zählt kräftige Farbpixel nach Farbton
String farbeImBereich(Bild b, double x0, double y0, double x1, double y1) {
  final xa = x0.floor().clamp(0, b.w - 1), xb = x1.ceil().clamp(0, b.w - 1);
  final ya = y0.floor().clamp(0, b.h - 1), yb = y1.ceil().clamp(0, b.h - 1);
  final zaehler = <String, int>{};
  final schritt = ((xb - xa) * (yb - ya) > 40000) ? 2 : 1;
  for (var y = ya; y <= yb; y += schritt) {
    for (var x = xa; x <= xb; x += schritt) {
      final r = b.r(x, y) / 255, g = b.g(x, y) / 255, bl = b.b(x, y) / 255;
      final mx = [r, g, bl].reduce((p, q) => p > q ? p : q);
      final mn = [r, g, bl].reduce((p, q) => p < q ? p : q);
      if (mx < 0.35 || mx == 0 || (mx - mn) / mx < 0.45) continue;
      final d = mx - mn;
      double h;
      if (mx == r) {
        h = 60 * (((g - bl) / d) % 6);
      } else if (mx == g) {
        h = 60 * ((bl - r) / d + 2);
      } else {
        h = 60 * ((r - g) / d + 4);
      }
      if (h < 0) h += 360;
      final f = h < 20 || h >= 335
          ? 'rot'
          : h < 38
              ? null // Orange/Braun: Holz und Rahmen ignorieren
              : h < 68
                  ? 'gelb'
                  : h < 165
                      ? 'gruen'
                      : h < 255
                          ? 'blau'
                          : 'lila';
      if (f != null) zaehler[f] = (zaehler[f] ?? 0) + 1;
    }
  }
  if (zaehler.isEmpty) return '';
  final best = zaehler.entries.reduce((p, q) => p.value >= q.value ? p : q);
  final summe = zaehler.values.reduce((p, q) => p + q);
  return best.value >= summe * 0.35 ? best.key : '';
}

/// Alle Truppen im Screenshot finden
List<TruppenTreffer> truppenAusText(List<TextZeile> zeilen, TruppenWissen w, {Bild? bild}) {
  final out = <TruppenTreffer>[];
  final benutzt = <TextZeile>{};
  for (final z in zeilen) {
    final t = truppeAusName(z.text, w);
    if (t == null) continue;
    // Level: in derselben Zeile oder in der nächsten Zeile darunter/daneben
    var level = levelAus(z.text);
    if (level == null) {
      final hoehe = (z.y1 - z.y0).abs().clamp(8, 200).toDouble();
      TextZeile? naechste;
      var abstand = double.infinity;
      for (final k in zeilen) {
        if (identical(k, z) || benutzt.contains(k) || levelAus(k.text) == null) continue;
        final dy = (k.my - z.my).abs(), dx = (k.mx - z.mx).abs();
        if (dy > hoehe * 6 || dx > hoehe * 12) continue;
        final d = dy * 2 + dx;
        if (d < abstand) {
          abstand = d;
          naechste = k;
        }
      }
      if (naechste != null) {
        level = levelAus(naechste.text);
        benutzt.add(naechste);
      }
    }
    var farbe = t.$1;
    if (farbe.isEmpty && bild != null) {
      final hoehe = (z.y1 - z.y0).abs();
      final breite = (z.x1 - z.x0).abs();
      // Bereich um den Namen (Truppenbild liegt meist darüber)
      farbe = farbeImBereich(bild, z.x0 - breite * 0.2, z.y0 - hoehe * 6, z.x1 + breite * 0.2, z.y1 + hoehe);
    }
    final maxLv = t.$2 == 'leg' ? 40 : 30;
    out.add(TruppenTreffer(
      farbe: farbe,
      typ: t.$2,
      legName: t.$3,
      level: (level ?? 1).clamp(1, maxLv),
      gelesen: z.text,
    ));
  }
  return out;
}
