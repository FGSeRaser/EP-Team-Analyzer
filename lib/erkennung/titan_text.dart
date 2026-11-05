// E&P Team-Analyzer – Titan aus einem Screenshot: Farbe, Sterne, Besonderheiten
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Die Farbe kommt aus den Bildpixeln (der Titan füllt die Bildmitte), Sterne und
// Besonderheiten aus der Texterkennung. Ergebnis ist ein Vorschlag zum Prüfen.

import '../daten/titan.dart';
import 'erkennung.dart';
import 'kartentext.dart';
import 'truppen_text.dart' show farbeImBereich;

class TitanErkannt {
  final String? farbe;
  final int? sterne;
  final bool selten;
  final Set<String> eigenschaften;
  const TitanErkannt({this.farbe, this.sterne, this.selten = false, this.eigenschaften = const {}});

  /// Erkanntes in eine bestehende Auswahl übernehmen
  TitanInfo anwenden(TitanInfo alt) {
    final neu = alt.kopie();
    if (farbe != null) neu.farbe = farbe!;
    if (sterne != null) neu.sterne = sterne!;
    if (selten) neu.selten = true;
    neu.eigenschaften.addAll(eigenschaften);
    return neu;
  }
}

final _sterneMuster = [
  RegExp(r'(\d{1,2})\s*[★☆✩✭✮*]'),
  RegExp(r'[★☆✩✭✮]\s*(\d{1,2})'),
  RegExp(r'(\d{1,2})\s*-?\s*(?:sterne|stern|star|stars)\b', caseSensitive: false),
  RegExp(r'titan\s*(?:lvl|level|stufe)?\s*(\d{1,2})\b', caseSensitive: false),
];

TitanErkannt titanAusText(List<TextZeile> zeilen, {Bild? bild}) {
  int? sterne;
  var selten = false;
  final fx = <String>{};
  String? farbeText;
  for (final z in zeilen) {
    final k = z.text.toLowerCase();
    if (sterne == null) {
      for (final m in _sterneMuster) {
        final x = m.firstMatch(z.text);
        final v = x == null ? null : int.tryParse(x.group(1)!);
        if (v != null && v >= 1 && v <= 20) {
          sterne = v;
          break;
        }
      }
    }
    if (RegExp(r'(selten|rare|mythi)').hasMatch(k)) selten = true;
    if (RegExp(r'(reflekt|reflect|spiegel|mirror)').hasMatch(k)) fx.add('reflekt');
    if (RegExp(r'(bonus)').hasMatch(k)) fx.add('bonus');
    if (RegExp(r'(feuer|fire)').hasMatch(k)) farbeText ??= 'rot';
    if (RegExp(r'\b(eis|ice|frost)').hasMatch(k)) farbeText ??= 'blau';
    if (RegExp(r'(natur|nature)').hasMatch(k)) farbeText ??= 'gruen';
    if (RegExp(r'(heilig|holy)').hasMatch(k)) farbeText ??= 'gelb';
    if (RegExp(r'(finster|dark)').hasMatch(k)) farbeText ??= 'lila';
  }
  String? farbe = farbeText;
  if (farbe == null && bild != null) {
    // Der Titan steht groß in der Bildmitte
    final f = farbeImBereich(bild, bild.w * 0.15, bild.h * 0.12, bild.w * 0.85, bild.h * 0.55);
    if (f.isNotEmpty) farbe = f;
  }
  return TitanErkannt(farbe: farbe, sterne: sterne, selten: selten, eigenschaften: fx);
}
