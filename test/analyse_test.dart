// Tests für die Analyse-Logik – Autor: FGSeRaser (github.com/FGSeRaser)

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ep_team_analyzer/daten/analyse.dart';
import 'package:ep_team_analyzer/daten/datenbank.dart';
import 'package:ep_team_analyzer/daten/namen_suche.dart';
import 'package:ep_team_analyzer/daten/werte.dart';
import 'package:ep_team_analyzer/erkennung/erkennung.dart';
import 'package:ep_team_analyzer/erkennung/kartentext.dart';

Datenbank _lade() {
  final j = jsonDecode(File('assets/data/helden.json').readAsStringSync()) as Map<String, dynamic>;
  final helden = (j['helden'] as List).map((x) => Held.ausJson(x as Map<String, dynamic>)).toList();
  final bedrohungen = <String, Bedrohung>{};
  (j['bedrohungen'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    bedrohungen[k] = Bedrohung(k, m['label'] as String, List<String>.from(m['counters'] as List), '');
  });
  final effekte = <String, Effekt>{};
  (j['effekte'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    effekte[k] = Effekt(k, m['l'] as String, m['g'] as String);
  });
  return Datenbank(
    version: 'test',
    quelle: '',
    effekte: effekte,
    bedrohungen: bedrohungen,
    leidenBedrohungen: Set<String>.from(j['leidenBedrohungen'] as List),
    rollen: const {},
    passive: const {},
    familien: const {},
    helden: helden,
  );
}

void main() {
  final db = _lade();

  test('Edwin hat die richtigen Max-Werte', () {
    final edwin = db.nachId['halloween_edwin']!;
    expect(edwin.werte[2], [1137, 1097, 2087, 1122]);
    expect(edwin.effekte, contains('hit_aoe'));
    expect(edwin.effekte, contains('bypass'));
  });

  test('Team ohne Reiniger hat Lücke bei Mana-Verlangsamung', () {
    final team = [db.nachId['halloween_edwin']!];
    final b = Analyse(db).team(team);
    expect(b.luecken, contains('mana_debuff'));
  });

  test('Werteformel: Stufe/Level/LB wie im Spiel', () {
    final edwin = db.nachId['halloween_edwin']!;
    final max = berechne(5, edwin.basis, 4, 80, 0);
    expect([max.angriff, max.verteidigung, max.leben], [922, 889, 1693]);
    final lb2 = berechne(5, edwin.basis, 4, 90, 2);
    expect([lb2.angriff, lb2.verteidigung, lb2.leben, lb2.kraft], [1137, 1097, 2087, 1122]);
    expect(maxLevel(5, 4, 1), 85);
    expect(maxLevel(4, 2, 0), 50);
  });

  test('Namenssuche findet Helden auch mit Tippfehler', () {
    expect(sucheNamen(db, 'Vivica').first.name, 'Vivica');
    expect(sucheNamen(db, 'vivika').map((h) => h.name), contains('Vivica'));
    final z = zeilenLesen('2x Kiril\nTelluria x3, Proteus');
    expect(z.map((e) => e.anzahl).toList(), [2, 3, 1]);
    expect(z.map((e) => e.name).toList(), ['Kiril', 'Telluria', 'Proteus']);
  });

  test('Farb-Histogramm-Fächer wie in Python', () {
    expect(binIndex(30, 30, 30), 36);
    expect(binIndex(200, 200, 200), 39);
    expect(binIndex(220, 30, 30), 2);
    expect(binIndex(30, 200, 40), 14);
  });

  test('Porträt-Fingerabdrücke passen zur Datenbank', () {
    final meta = jsonDecode(File('assets/data/portraits.json').readAsStringSync()) as Map<String, dynamic>;
    final roh = File('assets/data/portraits.bin').readAsBytesSync();
    final ids = List<String>.from(meta['ids'] as List);
    expect(roh.length, ids.length * (tw * th * 3 + bins));
    expect(ids, contains('halloween_edwin'));
  });

  test('Kartentext: Name, Level, Talent, Stärke – TEAM-Schild wird ignoriert', () {
    // Raster und Textpositionen wie in einem echten Screenshot (Heldenliste, 5 Spalten)
    const r = Raster(14.8, 195.3, 91.2, 123.6, 104.9, 256.0);
    final zellen = r.zellen(540, 940);
    final labblub = zellen.firstWhere((z) => z.zeile == 0 && z.spalte == 3);
    TextZeile zeile(String t, double x0, double y0, double x1, double y1) => TextZeile(t, x0 / 2, y0 / 2, x1 / 2, y1 / 2);
    final texte = [
      zeile('TEAM 3467', 655, 348, 820, 372), // über der Karte
      zeile('25', 805, 566, 840, 594), // Talent-Abzeichen
      zeile('LVL 90', 668, 645, 770, 672),
      zeile('Labblub', 668, 690, 790, 720),
      zeile('STÄRKE', 715, 765, 790, 782),
      zeile('1654', 705, 785, 800, 815),
      zeile('TEAM 3467', 655, 860, 820, 884), // Schild der nächsten Reihe
      zeile('1557', 920, 785, 1010, 815), // Nachbarkarte
    ];
    final k = kartenTextLesen(labblub, r, texte);
    expect(k.name, 'Labblub');
    expect(k.level, 90);
    expect(k.talent, 25);
    expect(k.staerke, 1654);
  });

  test('Level aus Screenshot -> Stufe und Limit Break', () {
    expect(standAusLevel(5, 90), (stufe: 4, level: 90, lb: 2));
    expect(standAusLevel(5, 85), (stufe: 4, level: 85, lb: 1));
    expect(standAusLevel(5, 80), (stufe: 4, level: 80, lb: 0));
    expect(standAusLevel(5, 70), (stufe: 3, level: 70, lb: 0));
    expect(standAusLevel(4, 75), (stufe: 4, level: 75, lb: 1));
  });
}
