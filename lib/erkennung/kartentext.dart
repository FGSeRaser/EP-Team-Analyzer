// E&P Team-Analyzer – Text unter den Heldenkarten auswerten (Name, Level, Talent, Stärke)
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Die Texterkennung (ML Kit) liefert Zeilen mit Position. Hier wird jede Zeile
// der passenden Karte zugeordnet. Kartenaufbau im Spiel (Heldenliste):
//   Porträt (mit Talent-Zahl rechts unten) – darunter "LVL 90", Name, Sterne, "STÄRKE 1406"

import 'erkennung.dart';

class TextZeile {
  final String text;
  final double x0, y0, x1, y1; // in Arbeitsbild-Koordinaten
  const TextZeile(this.text, this.x0, this.y0, this.x1, this.y1);
  double get mx => (x0 + x1) / 2;
  double get my => (y0 + y1) / 2;
}

class KartenText {
  final String? name;
  final int? level;
  final int? talent;
  final int? staerke;
  const KartenText({this.name, this.level, this.talent, this.staerke});
  bool get leer => name == null && level == null && staerke == null;
}

final _lvl = RegExp(r'L\s*[VY]\s*L\.?\s*(\d{1,3})', caseSensitive: false);
final _zahl = RegExp(r'^\d{1,4}$');
final _staerkeWort = RegExp(r'ST[AÄ]RKE|POWER|STRENGTH', caseSensitive: false);
final _rauschen = RegExp(r'TEAM|LVL|ST[AÄ]RKE', caseSensitive: false);

KartenText kartenTextLesen(Zelle z, Raster r, List<TextZeile> zeilen) {
  final pw = z.x1 - z.x0, ph = z.y1 - z.y0;
  // Bis knapp über die nächste Kartenreihe – die "TEAM …"-Schilder darüber gehören nicht dazu
  final unterBis = z.y1 + (r.dy - ph) * 0.75;
  int? level, talent, staerke;
  double staerkeY = -1;
  String? name;

  for (final t in zeilen) {
    final text = t.text.trim();
    if (text.isEmpty) continue;
    final inSpalte = t.mx >= z.x0 - 0.08 * pw && t.mx <= z.x1 + 0.08 * pw;
    if (!inSpalte) continue;

    // Talent-Zahl: rechts unten IM Porträt
    if (t.my >= z.y0 + 0.4 * ph && t.my <= z.y1 + 0.05 * ph && t.mx >= z.x0 + 0.55 * pw) {
      if (_zahl.hasMatch(text) && text.length <= 2) {
        final v = int.parse(text);
        if (v >= 1 && v <= 25) talent = v;
        continue;
      }
    }

    // Textblock unter dem Porträt
    if (t.my < z.y1 - 0.05 * ph || t.my > unterBis) continue;
    final m = _lvl.firstMatch(text);
    if (m != null) {
      level = int.tryParse(m.group(1)!);
      continue;
    }
    if (_staerkeWort.hasMatch(text)) {
      final zahl = RegExp(r'(\d{3,4})').firstMatch(text);
      if (zahl != null) staerke = int.parse(zahl.group(1)!);
      continue;
    }
    if (_zahl.hasMatch(text) && text.length >= 3) {
      // Stärke ist die unterste Zahl der Karte
      if (t.my > staerkeY) {
        staerke = int.parse(text);
        staerkeY = t.my;
      }
      continue;
    }
    // "LVL" und Zahl als getrennte Zeilen: kurze Zahl im oberen Teil des Textblocks
    if (_zahl.hasMatch(text) && t.my < z.y1 + 0.3 * (unterBis - z.y1)) {
      final v = int.parse(text);
      if (v >= 1 && v <= 90) level ??= v;
      continue;
    }
    if (_rauschen.hasMatch(text)) continue;
    final buchstaben = text.replaceAll(RegExp(r'[^A-Za-zÄÖÜäöüß]'), '');
    if (buchstaben.length >= 3 && (name == null || buchstaben.length > name.length)) {
      name = text.replaceAll(RegExp(r'[^A-Za-zÄÖÜäöüß\- ]'), '').trim();
    }
  }
  return KartenText(name: name, level: level, talent: talent, staerke: staerke);
}
