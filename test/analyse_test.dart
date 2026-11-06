// Tests für die Analyse-Logik – Autor: FGSeRaser (github.com/FGSeRaser)

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ep_team_analyzer/daten/analyse.dart';
import 'package:ep_team_analyzer/daten/datenbank.dart';
import 'package:ep_team_analyzer/daten/namen_suche.dart';
import 'package:ep_team_analyzer/daten/werte.dart';
import 'package:ep_team_analyzer/daten/sammlung.dart';
import 'package:ep_team_analyzer/erkennung/erkennung.dart';
import 'package:ep_team_analyzer/erkennung/kartentext.dart';
import 'package:ep_team_analyzer/erkennung/truppen_text.dart';
import 'package:ep_team_analyzer/erkennung/titan_text.dart';
import 'package:ep_team_analyzer/daten/titan.dart';
import 'package:ep_team_analyzer/daten/gegner_stand.dart';
import 'package:ep_team_analyzer/daten/talente.dart';
import 'package:ep_team_analyzer/daten/news.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ep_team_analyzer/daten/team_builder.dart';
import 'package:ep_team_analyzer/daten/truppen.dart';
import 'package:ep_team_analyzer/daten/truppen_besitz.dart';

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
    truppenRoh: (j['truppen'] as Map<String, dynamic>?) ?? const {},
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

  test('Team-Builder baut gültige Teams aus einer Sammlung', () {
    final pool = db.helden.where((h) => !h.kommend && h.sterne == 5 && h.kostuemVon == null).take(60).toList();
    final b = TeamBuilder(Analyse(db));
    for (final m in [Modus.verteidigung, Modus.angriff, Modus.titan]) {
      final v = b.baue(pool, m, titanFarbe: 'rot');
      expect(v, isNotEmpty);
      expect(v.first.helden.length, 5);
      expect(v.first.helden.map((h) => h.basisId).toSet().length, 5);
    }
    final krieg = b.krieg(pool);
    expect(krieg.length, 6);
    final alle = krieg.expand((t) => t.helden.map((h) => h.basisId)).toList();
    expect(alle.toSet().length, alle.length); // jeder Held nur einmal
  });

  test('Gegner-Analyse: Chance zwischen 3 und 97 %, Farbvorteil zählt', () {
    final pool = db.helden.where((h) => !h.kommend && h.sterne == 5 && h.kostuemVon == null).take(80).toList();
    final gegner = pool.skip(60).take(5).toList();
    final b = TeamBuilder(Analyse(db));
    final v = b.baue(pool.take(60).toList(), Modus.gegner, gegner: gegner);
    expect(v, isNotEmpty);
    expect(v.first.chance, inInclusiveRange(3, 97));
    expect(farbVorteil('rot', 'gruen'), 1);
    expect(farbVorteil('gruen', 'rot'), -1);
    expect(farbVorteil('gelb', 'lila'), 1);
  });

  test('Truppen: legendäre Truppe passt zur Klasse', () {
    final w = truppenVon(db);
    expect(w.legendaer.length, 20);
    final edwin = db.nachId['halloween_edwin']!; // Paladin
    final leg = w.legendaerFuer(edwin, Analyse(db));
    expect(leg, isNotEmpty);
    expect(leg.every((e) => e.legendaer!.klasse1 == 'paladin' || e.legendaer!.klasse2 == 'paladin'), isTrue);
    expect(w.epischFuer(edwin).length, 3);
  });

  test('Kostümbonus: Athena (Toon) mit 2 Kostümen, LB2, Talent 25 = 1751 wie im Spiel', () {
    final athena = db.nachId['ice_god_athena_costume_cute']!;
    final tabelle = db.kostuemTabelle(athena);
    expect(tabelle.length, 8); // 2 Kostüme × 4 Stufen
    final w = berechne(5, athena.basis, 4, 90, 2, talent: 25, kostuemBonus: kostuemBonusFuer(tabelle, 8));
    expect(w.kraft, 1751);
    // Rückrechnung aus der Spiel-Stärke
    final b = Besitz(id: athena.id, stufe: 4, level: 90, lb: 2, talent: 25, staerke: 1751);
    expect(Sammlung().kostuemStufenAusStaerke(db, athena, b), 8);
    expect(db.kostuemeVon(athena).length, 2);
  });

  test('Team-Builder: ausgewogene Teams – nie mehr als 2 Heiler oder 2 Sniper im Angriff', () {
    final pool = db.helden.where((h) => !h.kommend && h.sterne == 5 && h.kostuemVon == null).take(150).toList();
    final b = TeamBuilder(Analyse(db));
    for (final v in b.baue(pool, Modus.angriff)) {
      final rollen = v.helden.map(TeamBuilder.hauptRolle).toList();
      expect(rollen.where((r) => r == 'heiler').length, lessThanOrEqualTo(2), reason: rollen.join(','));
      expect(rollen.where((r) => r == 'sniper').length, lessThanOrEqualTo(2), reason: rollen.join(','));
      expect(v.aufgaben.length, 5);
    }
  });

  test('Truppen-Zuteilung: Farbe passt, jede Truppe einmal pro Team', () {
    final pool = db.helden.where((h) => !h.kommend && h.sterne == 5 && h.kostuemVon == null).take(60).toList();
    final inventar = [
      for (final f in ['rot', 'blau', 'gruen', 'gelb', 'lila']) ...[
        EigeneTruppe(id: 'm$f', farbe: f, typ: 'magie', level: 25),
        EigeneTruppe(id: 'k$f', farbe: f, typ: 'krit', level: 30),
      ],
    ];
    final b = TeamBuilder(Analyse(db), truppenInventar: inventar);
    final v = b.baue(pool, Modus.angriff).first;
    final ids = <String>[];
    for (final h in v.helden) {
      final tr = v.truppen[h.id];
      if (tr != null) {
        expect(tr.farbe, h.element);
        ids.add(tr.id);
      }
    }
    expect(ids.toSet().length, ids.length);
    final w = truppenVon(db);
    expect(EigeneTruppe(id: 'x', farbe: 'rot', typ: 'magie', level: 23).manaProzent(w), 17);
    expect(EigeneTruppe(id: 'y', farbe: 'rot', typ: 'krit', level: 30).kritProzent(w), 13);
  });

  test('Truppen-Fähigkeiten zählen in der Team-Analyse', () {
    final w = truppenVon(db);
    final h = db.helden.firstWhere((x) => x.sterne == 5 && x.element == 'rot' && !x.effekte.contains('crit_up'));
    final krit = EigeneTruppe(id: 'k', farbe: 'rot', typ: 'krit', level: 30);
    expect(w.truppenEffekte(krit, h).effekte, contains('crit_up'));
    final mit = w.teamMitTruppen([h], {h.id: krit}).first;
    expect(mit.effekte, contains('crit_up'));
    expect(h.effekte.contains('crit_up'), isFalse, reason: 'Original bleibt unverändert');
  });

  test('Neu würfeln liefert andere Teams, die trotzdem ausgewogen sind', () {
    final pool = db.helden.where((h) => !h.kommend && h.sterne == 4 && h.kostuemVon == null).take(120).toList();
    final erst = TeamBuilder(Analyse(db)).baue(pool, Modus.angriff);
    expect(erst, isNotEmpty);
    expect(erst.every((v) => v.helden.every((h) => h.sterne == 4)), isTrue);
    final gezeigt = [for (final v in erst) v.helden.map((h) => h.basisId).toSet()];
    final neu = TeamBuilder(Analyse(db), zufall: math.Random(7), schonGezeigt: gezeigt).baue(pool, Modus.angriff);
    expect(neu, isNotEmpty);
    for (final v in neu) {
      final ids = v.helden.map((h) => h.basisId).toSet();
      expect(gezeigt.any((g) => g.length == ids.length && g.containsAll(ids)), isFalse, reason: 'kein Team doppelt');
      final rollen = v.helden.map(TeamBuilder.hauptRolle).toList();
      expect(rollen.where((r) => r == 'heiler').length, lessThanOrEqualTo(2));
    }
  });

  test('Truppen aus Screenshot-Text: Name, Level und Farbe', () {
    final w = truppenVon(db);
    final zeilen = [
      const TextZeile('Mystic Mages', 100, 400, 260, 420),
      const TextZeile('Level 23/30', 110, 425, 240, 440),
      const TextZeile('Divine Wizards', 400, 400, 560, 420),
      const TextZeile('Lvl 17', 420, 425, 500, 440),
      const TextZeile('Mana +5 %', 100, 500, 200, 520),
    ];
    final t = truppenAusText(zeilen, w);
    expect(t.length, 2);
    expect((t[0].farbe, t[0].typ, t[0].level), ('lila', 'mana', 23));
    expect((t[1].farbe, t[1].typ, t[1].level), ('gelb', 'magie', 17));
    expect(truppeAusName('Barbaric Alpha Minotaur', w)?.$2, 'krit');
    // Farbe aus Pixeln: komplett blaues Bild
    final rgba = Uint8List(20 * 20 * 4);
    for (var i = 0; i < 400; i++) {
      rgba[i * 4] = 30;
      rgba[i * 4 + 1] = 80;
      rgba[i * 4 + 2] = 220;
      rgba[i * 4 + 3] = 255;
    }
    expect(farbeImBereich(Bild(rgba, 20, 20), 0, 0, 19, 19), 'blau');
  });

  test('Titan: Spielplan mit Farbe, Schwachpunkt und Zünd-Reihenfolge', () {
    final pool = db.helden.where((h) => !h.kommend && h.sterne == 5 && h.kostuemVon == null).take(150).toList();
    final ti = TitanInfo(farbe: 'gruen', sterne: 12, eigenschaften: {'reflekt'});
    final v = TeamBuilder(Analyse(db), titan: ti).baue(pool, Modus.titan, titanFarbe: 'gruen');
    expect(v, isNotEmpty);
    final plan = v.first.plan.join('\n');
    expect(plan, contains('Schwachpunkt'));
    expect(plan, contains('reflektiert'));
    expect(v.first.plan.first, startsWith('Zünd-Reihenfolge'));
    // Mehrheit mit Farbvorteil (rot gegen grün)
    expect(v.first.helden.where((h) => h.element == 'rot').length, greaterThanOrEqualTo(3));
  });

  test('Gegner: Spielplan nennt Ziel und Gegner-Stand rechnet Kostüme ein', () {
    final pool = db.helden.where((h) => !h.kommend && h.sterne == 5 && h.kostuemVon == null).take(100).toList();
    final gegner = db.helden.where((h) => !h.kommend && h.sterne == 5 && h.kostuemVon == null).skip(200).take(5).toList();
    final v = TeamBuilder(Analyse(db)).baue(pool, Modus.gegner, gegner: gegner);
    expect(v.first.plan.any((p) => p.startsWith('Zuerst ausschalten')), isTrue);
    final athena = db.nachId[db.nachId['ice_god_athena_costume_cute']!.basisId]!;
    final ohne = GegnerStand.standard(athena);
    final mit = GegnerStand.standard(athena)..kost = {for (final k in db.kostuemeVon(athena)) k.id: db.kostuemStufen(athena)};
    expect(mit.kraft(db, athena), greaterThan(ohne.kraft(db, athena)));
    expect((GegnerStand.standard(athena)..staerke = 1234).kraft(db, athena), 1234);
  });

  test('Titan aus Screenshot-Text', () {
    final e = titanAusText(const [TextZeile('Titan 11★', 0, 0, 50, 10), TextZeile('Reflektiert Schaden', 0, 20, 90, 30), TextZeile('Natur', 0, 40, 30, 50)]);
    expect(e.sterne, 11);
    expect(e.farbe, 'gruen');
    expect(e.eigenschaften, contains('reflekt'));
  });

  test('Hero-Analyser: Talent-Raster und Empfehlung je Einsatz', () {
    final raster = TalentRaster.ausJson(File('assets/data/talente.json').readAsStringSync());
    expect(raster.length, 10);
    final monk = raster['monk']!;
    expect(monk.gabeln.length, 9);
    expect(monk.pflicht.firstWhere((k) => k.nr == 10).typ, 'crit');
    expect(monk.pflicht.firstWhere((k) => k.nr == 20).typ, 'mana');

    final held = db.helden.firstWhere((h) =>
        !h.kommend && h.sterne == 5 && h.kostuemVon == null && raster.containsKey(h.klasseKey) && h.effekte.contains('hit_single'));
    final st = GegnerStand.standard(held).werte(db, held);
    final r = raster[held.klasseKey]!;
    final titan = TalentAnalyse.empfehlen(held, r, st, Einsatz.titan, 'flanke');
    final tank = TalentAnalyse.empfehlen(held, r, st, Einsatz.verteidigung, 'tank');
    expect(titan.summe['atk']!, greaterThan(tank.summe['atk']!));
    expect(tank.summe['def']! + tank.summe['hp']!, greaterThan(titan.summe['def']! + titan.summe['hp']!));
    expect(tank.positionen.length, 3);
    expect(titan.gabeln.length, 9);
    expect(TalentAnalyse.empfehlen(held, r, st, Einsatz.titan, 'flanke', meister: false).gabeln.length, 7);
  });

  test('News: Held des Monats, erwähnte Helden, News-Datei', () {
    final hdm = heldenDesMonats(db, 2026, 11);
    expect(hdm, isNotEmpty);
    expect(hdm.first.sterne, 5);
    final namen = erwaehnteHelden(db, 'Balance changes: Adelitza gets +10% damage.').map((h) => h.nameEn);
    expect(namen, contains('Adelitza'));
    final j = jsonDecode(File('news/news.json').readAsStringSync()) as Map<String, dynamic>;
    final artikel = [for (final a in j['artikel'] as List) NewsArtikel.ausJson(a as Map<String, dynamic>)];
    expect(artikel, isNotEmpty);
    expect(artikel.first.titel, isNotEmpty);
    final t = EventTermin.ausJson({'name': 'Goblin Village', 'symbol': '👺', 'start': '2026-11-20T07:00Z', 'ende': '2026-11-24T07:00Z', 'artikel': ''});
    expect(t.dauer.inDays, 4);
    expect(t.laeuft(DateTime.utc(2026, 11, 21)), isTrue);
    expect(t.laeuft(DateTime.utc(2026, 11, 25)), isFalse);
  });

  test('„Kommt“ endet am Erscheinungstag automatisch', () {
    final j = jsonDecode(File('assets/data/helden.json').readAsStringSync()) as Map<String, dynamic>;
    final roh = Map<String, dynamic>.from((j['helden'] as List).first as Map);
    expect(Held.ausJson({...roh, 'neu': 1, 'd': '2000-01-01'}).kommend, isFalse);
    expect(Held.ausJson({...roh, 'neu': 1, 'd': '2999-01-01'}).kommend, isTrue);
    expect(Held.ausJson({...roh, 'neu': 1, 'd': ''}).kommend, isTrue);
    final stand = jsonDecode(File('assets/data/stand.json').readAsStringSync()) as Map<String, dynamic>;
    expect((stand['dateien'] as Map).length, 4);
  });
}
