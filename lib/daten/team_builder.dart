// E&P Team-Analyzer – Team-Builder und Gegner-Analyse
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Baut aus der eigenen Sammlung die besten 5er-Teams je Spielmodus und schätzt
// gegen ein Gegnerteam die Gewinnchance. Die Chance ist eine SCHÄTZUNG aus
// Stärke, Farbvorteil, Kontern und Grundbausteinen – kein Kampfsimulator.

import 'dart:math' as math;

import 'analyse.dart';
import 'datenbank.dart';
import 'sprache.dart';

enum Modus { verteidigung, angriff, krieg, titan, gegner }

String modusName(Modus m) => switch (m) {
      Modus.verteidigung => tx('Verteidigung', 'Defense'),
      Modus.angriff => tx('Angriff / Raid', 'Attack / raid'),
      Modus.krieg => tx('Krieg (6 Teams)', 'War (6 teams)'),
      Modus.titan => 'Titan',
      Modus.gegner => tx('Gegen ein Team', 'Against a team'),
    };

/// Farbe schlägt Farbe: Feuer > Natur > Eis > Feuer, Heilig <> Finster
const Map<String, String> staerkerAls = {
  'rot': 'gruen',
  'gruen': 'blau',
  'blau': 'rot',
  'gelb': 'lila',
  'lila': 'gelb',
};

/// +1 = Angreifer im Vorteil (doppelter Schaden), -1 = im Nachteil (halber Schaden)
int farbVorteil(String angreifer, String ziel) {
  if (staerkerAls[angreifer] == ziel) return 1;
  if (staerkerAls[ziel] == angreifer) return -1;
  return 0;
}

/// Welche Farbe ist stark gegen [ziel]?
String? starkGegen(String ziel) {
  for (final e in staerkerAls.entries) {
    if (e.value == ziel) return e.key;
  }
  return null;
}

class TeamVorschlag {
  /// Bei Verteidigung in Aufstellung: Flanke, Flügel, Tank, Flügel, Flanke
  final List<Held> helden;
  final double wert;
  final int? chance;
  final List<String> staerken;
  final List<String> schwaechen;
  const TeamVorschlag(this.helden, this.wert, {this.chance, this.staerken = const [], this.schwaechen = const []});
}

class TeamBuilder {
  final Analyse a;

  /// Stärke je Held-ID (z. B. aus der Sammlung / dem Screenshot); sonst Max-Stärke
  final Map<String, int> kraftVon;

  /// Stärke der Gegner-Helden (aus dem Gegner-Screenshot). Ohne Angabe:
  /// Max-Stärke +10 % (Gegner haben meist Embleme, die eigene Stärke aus dem Spiel enthält sie auch)
  final Map<String, int> gegnerKraft;
  final Map<String, Map<String, int>> _rollenCache = {};

  TeamBuilder(this.a, {this.kraftVon = const {}, this.gegnerKraft = const {}});

  int kraftGegner(Held h) => gegnerKraft[h.id] ?? (h.kraft * 1.1).round();

  Datenbank get db => a.db;
  int kraft(Held h) => kraftVon[h.id] ?? h.kraft;
  Map<String, int> rollen(Held h) => _rollenCache.putIfAbsent(h.id, () => a.rollenWerte(h));

  static bool _hat(List<Held> t, List<String> fx) => t.any((h) => fx.any(h.effekte.contains));

  static const _heilung = ['heal', 'heal_ot', 'health_boost', 'lifesteal'];
  static const _reinigen = ['cleanse', 'ailment_immune', 'ailment_block'];
  static const _bannen = ['dispel', 'steal_buff'];
  static const _flaeche = ['hit_aoe', 'hit_three'];
  static const _vertRunter = ['def_down', 'elem_def_down', 'dmg_taken_up'];
  static const _manaKontrolle = ['mana_debuff', 'mana_cut', 'special_block'];

  static double _tempoWert(String t) => switch (t) {
        'very_fast' => 1.0,
        'fast' => 0.85,
        'average' => 0.6,
        'slow' => 0.35,
        'very_slow' => 0.2,
        _ => 0.6,
      };

  // ------------------------------------------------------------------------
  // Bewertung eines Teams
  // ------------------------------------------------------------------------
  double teamWert(List<Held> t, Modus m, {String? titanFarbe, List<Held> gegner = const []}) {
    if (t.isEmpty) return 0;
    if (m == Modus.gegner && gegner.isNotEmpty) {
      return _logit(t, gegner) + 0.2 * _kraftAnteil(t);
    }
    final kraftA = _kraftAnteil(t);
    final tempo = t.map((h) => _tempoWert(h.tempoId)).reduce((x, y) => x + y) / t.length;

    double b(List<String> fx, double gewicht) => _hat(t, fx) ? gewicht : 0;
    double bausteine;
    double maxB;
    switch (m) {
      case Modus.verteidigung:
        final tank = t.map((h) => rollen(h)['tank'] ?? 0).reduce(math.max) / 100;
        bausteine = b(_heilung, 1) + b(_reinigen, 1) + b(_bannen, 0.8) + b(_flaeche, 1) + b(_manaKontrolle, 0.8) + 1.5 * tank;
        maxB = 6.1;
        final farben = t.map((h) => h.element).toSet().length;
        bausteine += farben >= 3 ? 0.3 : 0;
        maxB += 0.3;
      case Modus.titan:
        bausteine = b(['def_down'], 2) + b(['atk_up'], 1.5) + b(['elem_def_down', 'dmg_taken_up'], 1) +
            b(_heilung, 0.7) + b(['crit_up'], 0.5) + b(_reinigen, 0.3);
        maxB = 6;
        if (titanFarbe != null) {
          final vorteil = t.map((h) => farbVorteil(h.element, titanFarbe)).reduce((x, y) => x + y) / t.length;
          bausteine += 2.5 * vorteil;
          maxB += 2.5;
        }
      default: // Angriff, Krieg
        bausteine = b(_heilung, 1) + b(_reinigen, 1) + b(_bannen, 1) + b(_vertRunter, 1) + b(['atk_up'], 0.8) +
            b(_flaeche, 1);
        maxB = 5.8;
    }
    // Zweiter Heiler/Reiniger hilft auch noch etwas
    if (t.where((h) => _heilung.any(h.effekte.contains)).length >= 2) bausteine += 0.2;
    final familien = <String, int>{};
    for (final h in t) {
      if (h.familie.isNotEmpty) familien[h.familie] = (familien[h.familie] ?? 0) + 1;
    }
    final familienBonus = familien.values.where((n) => n >= 2).length * 0.03;

    return 0.40 * kraftA + 0.45 * (bausteine / maxB) + (m == Modus.verteidigung ? 0.05 : 0.15) * tempo + familienBonus;
  }

  double _kraftAnteil(List<Held> t) =>
      (t.map(kraft).reduce((x, y) => x + y) / t.length / 1500).clamp(0.0, 1.3).toDouble();

  // ------------------------------------------------------------------------
  // Gegner: geschätzte Gewinnchance
  // ------------------------------------------------------------------------
  double _logit(List<Held> t, List<Held> gegner, {List<String>? gruende, List<String>? probleme}) {
    var l = 0.0;
    // 1) Stärke
    final eigene = t.map(kraft).reduce((x, y) => x + y) / t.length;
    final fremde = gegner.map(kraftGegner).reduce((x, y) => x + y) / gegner.length;
    final verhaeltnis = fremde <= 0 ? 1.0 : eigene / fremde;
    l += 4 * math.log(verhaeltnis.clamp(0.5, 2.0));
    if (verhaeltnis > 1.05) gruende?.add(tx('Stärker als der Gegner (${(verhaeltnis * 100 - 100).round()} %)', 'Stronger than the enemy (${(verhaeltnis * 100 - 100).round()}%)'));
    if (verhaeltnis < 0.95) probleme?.add(tx('Schwächer als der Gegner (${(100 - verhaeltnis * 100).round()} %)', 'Weaker than the enemy (${(100 - verhaeltnis * 100).round()}%)'));

    // 2) Farben – vor allem gegen den Tank (Mitte)
    final tank = gegner.length >= 3 ? gegner[2] : gegner.first;
    var farbe = 0.0;
    var gegenTank = 0;
    for (final h in t) {
      final v = farbVorteil(h.element, tank.element);
      gegenTank += v;
      farbe += 0.18 * v;
      for (final g in gegner) {
        if (!identical(g, tank)) farbe += 0.05 * farbVorteil(h.element, g.element);
      }
    }
    l += farbe;
    final stark = starkGegen(tank.element);
    if (gegenTank >= 2) gruende?.add(tx('$gegenTank Helden mit Farbvorteil gegen den Tank ${tank.nameL}', '$gegenTank heroes strong against the tank ${tank.nameL}'));
    if (gegenTank <= -1) {
      probleme?.add(tx('Farbnachteil gegen den Tank ${tank.nameL}${stark == null ? '' : ' – besser ${_farbName(stark)} nehmen'}',
          'Color disadvantage vs the tank ${tank.nameL}${stark == null ? '' : ' – better use ${_farbName(stark)}'}'));
    }

    // 3) Gefahren des Gegners: haben wir Konter?
    for (final key in wichtigeBedrohungen) {
      final bed = db.bedrohungen[key];
      if (bed == null) continue;
      final traeger = gegner.where((g) => g.effekte.contains(key)).toList();
      if (traeger.isEmpty) continue;
      final w = math.min(traeger.length, 2).toDouble();
      final hart = t.where((h) => bed.counters.any(h.effekte.contains)).toList();
      final weich = t.where((h) => bed.weich.any(h.effekte.contains)).toList();
      final immun = t.where((h) => a.schutz(h, key) >= 0.75).length;
      if (hart.isNotEmpty) {
        l += 0.22 * w;
        gruende?.add(tx('${bed.label} (${traeger.map((g) => g.nameL).join(', ')}) gekontert von ${hart.map((h) => h.nameL).join(', ')}',
            '${bed.label} (${traeger.map((g) => g.nameL).join(', ')}) countered by ${hart.map((h) => h.nameL).join(', ')}'));
      } else if (weich.isNotEmpty || immun >= 3) {
        l += 0.0;
      } else {
        l -= 0.22 * w;
        probleme?.add(tx('Keine Antwort auf ${bed.label} von ${traeger.map((g) => g.nameL).join(', ')}',
            'No answer to ${bed.label} from ${traeger.map((g) => g.nameL).join(', ')}'));
      }
    }

    // 4) Eigene Stärken, die der Gegner aushebelt
    var ausgehebelt = 0;
    for (final h in t) {
      for (final e in a.anfaelligFuer(h).entries) {
        if (gegner.any((g) => e.value.any(g.effekte.contains))) ausgehebelt++;
      }
    }
    l -= 0.06 * math.min(ausgehebelt, 6);
    if (ausgehebelt >= 3) {
      probleme?.add(tx('Der Gegner hebelt $ausgehebelt eurer Effekte aus (z. B. durch Bannen)', 'The enemy negates $ausgehebelt of your effects (e.g. by dispelling)'));
    }

    // 5) Grundbausteine
    if (!_hat(t, _heilung)) {
      l -= 0.3;
      probleme?.add(tx('Keine Heilung im Team', 'No healing in the team'));
    }
    if (!_hat(t, _vertRunter) && !_hat(t, ['atk_up'])) l -= 0.15;
    return l;
  }

  static String _farbName(String e) => switch (e) {
        'rot' => tx('Feuer (rot)', 'Fire (red)'),
        'blau' => tx('Eis (blau)', 'Ice (blue)'),
        'gruen' => tx('Natur (grün)', 'Nature (green)'),
        'gelb' => tx('Heilig (gelb)', 'Holy (yellow)'),
        'lila' => tx('Finster (lila)', 'Dark (purple)'),
        _ => e,
      };

  int chance(List<Held> t, List<Held> gegner) {
    final l = _logit(t, gegner);
    return (100 / (1 + math.exp(-l))).round().clamp(3, 97);
  }

  TeamVorschlag erklaere(List<Held> t, Modus m, {String? titanFarbe, List<Held> gegner = const []}) {
    final gut = <String>[];
    final schlecht = <String>[];
    int? ch;
    if (m == Modus.gegner && gegner.isNotEmpty) {
      final l = _logit(t, gegner, gruende: gut, probleme: schlecht);
      ch = (100 / (1 + math.exp(-l))).round().clamp(3, 97);
    } else {
      final bericht = a.team(t);
      for (final e in bericht.bausteine.entries) {
        if (e.value) gut.add(_bausteinName(e.key));
      }
      for (final k in bericht.abgedeckt.keys) {
        gut.add(tx('Gewappnet gegen ${db.bedrohungName(k)}', 'Prepared for ${db.bedrohungName(k)}'));
      }
      for (final k in bericht.luecken) {
        schlecht.add(tx('Schwach gegen ${db.bedrohungName(k)}', 'Weak against ${db.bedrohungName(k)}'));
      }
      for (final e in bericht.bausteine.entries) {
        if (!e.value) schlecht.add(tx('Fehlt: ${_bausteinName(e.key)}', 'Missing: ${_bausteinName(e.key)}'));
      }
      if (m == Modus.titan && titanFarbe != null) {
        final vorteil = t.where((h) => farbVorteil(h.element, titanFarbe) == 1).length;
        (vorteil >= 3 ? gut : schlecht).add(tx('$vorteil von ${t.length} Helden mit Farbvorteil gegen den Titan',
            '$vorteil of ${t.length} heroes strong against the titan'));
      }
    }
    final helden = m == Modus.verteidigung ? aufstellen(t) : t;
    return TeamVorschlag(helden, teamWert(t, m, titanFarbe: titanFarbe, gegner: gegner),
        chance: ch, staerken: gut, schwaechen: schlecht);
  }

  static String _bausteinName(String k) => Sprache.en
      ? const {
          'Heilung': 'Healing',
          'Reinigen': 'Cleanse',
          'Bannen': 'Dispel',
          'Flächenschaden': 'AoE damage',
          'Verteidigung runter': 'Defense down',
          'Angriff hoch': 'Attack up',
          'Mana-Kontrolle': 'Mana control',
        }[k] ?? k
      : k;

  /// Verteidigung: Tank in die Mitte, die beiden besten Flanken außen
  List<Held> aufstellen(List<Held> t) {
    if (t.length < 5) return t;
    final rest = [...t];
    rest.sort((x, y) => (rollen(y)['tank'] ?? 0).compareTo(rollen(x)['tank'] ?? 0));
    final tank = rest.removeAt(0);
    rest.sort((x, y) => (rollen(y)['flanke'] ?? 0).compareTo(rollen(x)['flanke'] ?? 0));
    return [rest[0], rest[2], tank, rest[3], rest[1]];
  }

  // ------------------------------------------------------------------------
  // Suche: gierig aufbauen, dann durch Tauschen verbessern
  // ------------------------------------------------------------------------
  List<TeamVorschlag> baue(
    List<Held> pool,
    Modus m, {
    int anzahl = 3,
    String? titanFarbe,
    List<Held> gegner = const [],
  }) {
    final kandidaten = _vorauswahl(pool, m, titanFarbe: titanFarbe, gegner: gegner);
    if (kandidaten.isEmpty) return const [];
    double wert(List<Held> t) => teamWert(t, m, titanFarbe: titanFarbe, gegner: gegner);

    final ergebnisse = <List<Held>>[];
    final startHelden = kandidaten.take(anzahl * 2).toList();
    for (final start in startHelden) {
      final team = _suche(kandidaten, [start], wert);
      final schluessel = (team.map((h) => h.basisId).toList()..sort()).join('|');
      if (ergebnisse.every((e) => (e.map((h) => h.basisId).toList()..sort()).join('|') != schluessel)) {
        ergebnisse.add(team);
      }
    }
    ergebnisse.sort((x, y) => wert(y).compareTo(wert(x)));
    return [
      for (final t in ergebnisse.take(anzahl)) erklaere(t, m, titanFarbe: titanFarbe, gegner: gegner),
    ];
  }

  /// Krieg: mehrere Teams, jeder Held nur einmal
  List<TeamVorschlag> krieg(List<Held> pool, {int teams = 6}) {
    final rest = [...pool];
    final out = <TeamVorschlag>[];
    for (var i = 0; i < teams; i++) {
      final v = baue(rest, Modus.krieg, anzahl: 1);
      if (v.isEmpty || v.first.helden.length < 5) break;
      out.add(v.first);
      final benutzt = v.first.helden.map((h) => h.basisId).toSet();
      rest.removeWhere((h) => benutzt.contains(h.basisId));
    }
    return out;
  }

  List<Held> _vorauswahl(List<Held> pool, Modus m, {String? titanFarbe, List<Held> gegner = const []}) {
    // Pro Basis-Held nur die stärkste Variante (Kostüm oder nicht) – man kann ja nur eine benutzen
    final bester = <String, Held>{};
    for (final h in pool) {
      final alt = bester[h.basisId];
      if (alt == null || kraft(h) > kraft(alt)) bester[h.basisId] = h;
    }
    final liste = bester.values.toList();
    double einzel(Held h) {
      final r = rollen(h);
      final rolle = switch (m) {
        Modus.verteidigung => math.max(r['tank'] ?? 0, r['flanke'] ?? 0),
        Modus.titan => r['angreifer'] ?? 0,
        _ => [r['angreifer'] ?? 0, r['heiler'] ?? 0, r['konter'] ?? 0].reduce(math.max),
      };
      var w = kraft(h) / 1500 + rolle / 100;
      if (m == Modus.titan && titanFarbe != null) w += 0.6 * farbVorteil(h.element, titanFarbe);
      if (m == Modus.gegner && gegner.isNotEmpty) {
        final tank = gegner.length >= 3 ? gegner[2] : gegner.first;
        w += 0.3 * farbVorteil(h.element, tank.element);
        w += 0.1 * a.hilftGegen(h).where((k) => gegner.any((g) => g.effekte.contains(k))).length;
      }
      return w;
    }

    final bewertet = {for (final h in liste) h: einzel(h)};
    liste.sort((x, y) => bewertet[y]!.compareTo(bewertet[x]!));
    return liste.take(45).toList();
  }

  List<Held> _suche(List<Held> kandidaten, List<Held> start, double Function(List<Held>) wert) {
    final team = [...start];
    while (team.length < 5 && team.length < kandidaten.length) {
      Held? bester;
      var besterWert = -1e9;
      for (final c in kandidaten) {
        if (team.any((h) => h.basisId == c.basisId)) continue;
        final w = wert([...team, c]);
        if (w > besterWert) {
          besterWert = w;
          bester = c;
        }
      }
      if (bester == null) break;
      team.add(bester);
    }
    // Tauschen, solange es besser wird
    var aktuell = wert(team);
    for (var runde = 0; runde < 3; runde++) {
      var verbessert = false;
      for (var i = 0; i < team.length; i++) {
        for (final c in kandidaten) {
          if (team.any((h) => h.basisId == c.basisId)) continue;
          final probe = [...team]..[i] = c;
          final w = wert(probe);
          if (w > aktuell + 1e-6) {
            team[i] = c;
            aktuell = w;
            verbessert = true;
          }
        }
      }
      if (!verbessert) break;
    }
    return team;
  }
}
