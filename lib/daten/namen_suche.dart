// E&P Team-Analyzer – Helden über eingetippte Namen finden (auch mit Tippfehlern)
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'dart:math' as math;

import 'datenbank.dart';

String normName(String s) {
  var t = s.toLowerCase().trim();
  const ersatz = {
    'ä': 'ae', 'ö': 'oe', 'ü': 'ue', 'ß': 'ss', 'é': 'e', 'è': 'e', 'ê': 'e', 'á': 'a', 'à': 'a',
    'â': 'a', 'í': 'i', 'ï': 'i', 'ó': 'o', 'ô': 'o', 'ú': 'u', 'ñ': 'n', 'ç': 'c', 'å': 'a', 'ø': 'o',
  };
  ersatz.forEach((a, b) => t = t.replaceAll(a, b));
  return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var vor = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final akt = List<int>.filled(b.length + 1, 0);
    akt[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final kosten = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      akt[j] = math.min(math.min(akt[j - 1] + 1, vor[j] + 1), vor[j - 1] + kosten);
    }
    vor = akt;
  }
  return vor[b.length];
}

/// Eine eingetippte Zeile: Name und Anzahl ("Vivica", "2x Vivica", "Vivica x2")
class Eingabe {
  final String text;
  final String name;
  final int anzahl;
  const Eingabe(this.text, this.name, this.anzahl);
}

List<Eingabe> zeilenLesen(String text) {
  final out = <Eingabe>[];
  for (final roh in text.split(RegExp(r'[\n;,]'))) {
    final z = roh.trim();
    if (z.isEmpty) continue;
    var name = z;
    var anzahl = 1;
    final vorne = RegExp(r'^(\d+)\s*[x×*]?\s+(.+)$').firstMatch(z);
    final hinten = RegExp(r'^(.+?)\s*[x×*]\s*(\d+)$').firstMatch(z);
    if (vorne != null) {
      anzahl = int.parse(vorne.group(1)!);
      name = vorne.group(2)!;
    } else if (hinten != null) {
      name = hinten.group(1)!;
      anzahl = int.parse(hinten.group(2)!);
    }
    out.add(Eingabe(z, name.trim(), anzahl.clamp(1, 99)));
  }
  return out;
}

/// Beste Kandidaten für einen Namen. Basis-Helden vor Kostümen,
/// erschienene vor kommenden, mehr Sterne zuerst.
List<Held> sucheNamen(Datenbank db, String eingabe, {int max = 6}) {
  final q = normName(eingabe);
  if (q.isEmpty) return const [];

  int rang(Held h) => (h.kostuemVon == null ? 0 : 10) + (h.kommend ? 100 : 0) + (5 - h.sterne);
  List<Held> sortiert(Iterable<Held> l) => (l.toList()..sort((a, b) => rang(a).compareTo(rang(b)))).take(max).toList();

  final exakt = db.helden.where((h) => normName(h.name) == q || normName(h.nameEn) == q);
  if (exakt.isNotEmpty) return sortiert(exakt);

  final anfang = db.helden.where((h) => normName(h.name).startsWith(q) || normName(h.nameEn).startsWith(q));
  if (anfang.isNotEmpty && q.length >= 3) return sortiert(anfang);

  final enthaelt = db.helden.where((h) => normName(h.name).contains(q) || normName(h.titel).contains(q));
  if (enthaelt.isNotEmpty && q.length >= 4) return sortiert(enthaelt);

  // Tippfehler: Abstand höchstens 1 (kurze Namen) bzw. 2
  final erlaubt = q.length <= 4 ? 1 : 2;
  final nah = <MapEntry<Held, int>>[];
  for (final h in db.helden) {
    final d = math.min(levenshtein(q, normName(h.name)), levenshtein(q, normName(h.nameEn)));
    if (d <= erlaubt) nah.add(MapEntry(h, d * 1000 + rang(h)));
  }
  nah.sort((a, b) => a.value.compareTo(b.value));
  return nah.take(max).map((e) => e.key).toList();
}
