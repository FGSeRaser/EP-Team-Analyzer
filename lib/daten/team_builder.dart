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
import 'truppen.dart';
import 'truppen_besitz.dart';

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

  /// Held-ID -> was er in diesem Team macht
  final Map<String, String> aufgaben;

  /// Held-ID -> zugeteilte eigene Truppe (falls Truppen eingetragen)
  final Map<String, EigeneTruppe> truppen;
  const TeamVorschlag(this.helden, this.wert,
      {this.chance,
      this.staerken = const [],
      this.schwaechen = const [],
      this.aufgaben = const {},
      this.truppen = const {}});
}

class TeamBuilder {
  final Analyse a;

  /// Stärke je Held-ID (z. B. aus der Sammlung / dem Screenshot); sonst Max-Stärke
  final Map<String, int> kraftVon;

  /// Stärke der Gegner-Helden (aus dem Gegner-Screenshot). Ohne Angabe:
  /// Max-Stärke +10 % (Gegner haben meist Embleme, die eigene Stärke aus dem Spiel enthält sie auch)
  final Map<String, int> gegnerKraft;
  final Map<String, Map<String, int>> _rollenCache = {};

  /// Eigene Truppen (für die Zuteilung)
  final List<EigeneTruppe> truppenInventar;

  TeamBuilder(this.a, {this.kraftVon = const {}, this.gegnerKraft = const {}, this.truppenInventar = const []});

  /// Jedem Helden die beste eigene Truppe seiner Farbe zuteilen (jede Truppe einmal pro Team)
  Map<String, EigeneTruppe> truppenZuteilen(List<Held> team, Modus m) {
    if (truppenInventar.isEmpty) return const {};
    final wissen = truppenVon(db);
    final rest = <EigeneTruppe, int>{for (final t in truppenInventar) t: t.anzahl};
    final out = <String, EigeneTruppe>{};
    // Langsame Helden zuerst – ihnen hilft Mana am meisten
    final reihenfolge = [...team]..sort((x, y) => tempoWert(x.tempoId).compareTo(tempoWert(y.tempoId)));
    for (final h in reihenfolge) {
      EigeneTruppe? beste;
      var besterWert = -1.0;
      for (final e in rest.entries) {
        if (e.value <= 0 || e.key.farbe != h.element) continue;
        final w = wissen.truppenWert(e.key, h, m, rollen(h));
        if (w > besterWert) {
          besterWert = w;
          beste = e.key;
        }
      }
      if (beste != null) {
        out[h.id] = beste;
        rest[beste] = rest[beste]! - 1;
      }
    }
    return out;
  }

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
  static const _schutz = ['def_up', 'dmg_reduction', 'special_def_up', 'share_damage'];
  static const _tankFx = ['taunt', 'def_up', 'counter', 'dmg_reduction', 'mimic', 'dodge'];

  /// Wie früh kommt die Spezialfähigkeit? (schnelle Helden machen ihre Aufgabe öfter)
  static double tempoWert(String t) => switch (t) {
        'very_fast' => 1.0,
        'fast' => 0.9,
        'average' => 0.75,
        'slow' => 0.55,
        'very_slow' => 0.4,
        _ => 0.75,
      };

  /// Aufgaben im Team je Modus: Name, Effekte, Gewicht, wie viele Helden sinnvoll sind
  List<Aufgabe> aufgaben(Modus m) => switch (m) {
        Modus.verteidigung => [
            Aufgabe('tank', tx('Tank', 'Tank'), _tankFx, 1.6, 1),
            Aufgabe('schaden', tx('Flächenschaden', 'AoE damage'), _flaeche, 1.2, 2),
            Aufgabe('mana', tx('Mana-Kontrolle', 'Mana control'), _manaKontrolle, 0.8, 1),
            Aufgabe('heilung', tx('Heilung', 'Healing'), _heilung, 0.8, 1),
            Aufgabe('bannen', tx('Bannen', 'Dispel'), _bannen, 0.6, 1),
            Aufgabe('reinigen', tx('Reinigen', 'Cleanse'), _reinigen, 0.6, 1),
            Aufgabe('vert', tx('Verteidigung runter', 'Defense down'), _vertRunter, 0.5, 1),
          ],
        Modus.titan => [
            Aufgabe('vert', tx('Verteidigung runter', 'Defense down'), _vertRunter, 2.2, 1),
            Aufgabe('angriff', tx('Angriff hoch', 'Attack up'), const ['atk_up'], 1.6, 1),
            Aufgabe('krit', tx('Krit hoch', 'Crit up'), const ['crit_up'], 0.6, 1),
            Aufgabe('heilung', tx('Heilung', 'Healing'), _heilung, 0.6, 1),
            Aufgabe('reinigen', tx('Reinigen', 'Cleanse'), _reinigen, 0.3, 1),
            Aufgabe('mana', tx('Mana hoch', 'Mana up'), const ['mana_up', 'mana_gain'], 0.4, 1),
          ],
        _ => [
            Aufgabe('heilung', tx('Heilung', 'Healing'), _heilung, 1.2, 1),
            Aufgabe('reinigen', tx('Reinigen', 'Cleanse'), _reinigen, 1.1, 1),
            Aufgabe('vert', tx('Verteidigung runter', 'Defense down'), _vertRunter, 1.2, 1),
            Aufgabe('bannen', tx('Bannen', 'Dispel'), _bannen, 1.0, 1),
            Aufgabe('schaden', tx('Schaden', 'Damage'), const ['hit_aoe', 'hit_three', 'hit_single', 'extra_attack'], 1.0, 2),
            Aufgabe('angriff', tx('Angriff hoch', 'Attack up'), const ['atk_up', 'crit_up'], 0.6, 1),
            Aufgabe('mana', tx('Mana-Kontrolle', 'Mana control'), _manaKontrolle, 0.5, 1),
            Aufgabe('schutz', tx('Schutz', 'Protection'), _schutz, 0.4, 1),
          ],
      };

  /// Erfüllung der Aufgaben: der schnellste passende Held zählt voll, weitere nur wenig
  ({double wert, double max, Map<String, List<String>> zuordnung}) _aufgabenWert(List<Held> t, Modus m) {
    var wert = 0.0, max = 0.0;
    final zuordnung = <String, List<String>>{};
    for (final auf in aufgaben(m)) {
      max += auf.gewicht * (auf.anzahl == 1 ? 1 : 1.5);
      final anbieter = t.where((h) => auf.effekte.any(h.effekte.contains)).toList()
        ..sort((x, y) => tempoWert(y.tempoId).compareTo(tempoWert(x.tempoId)));
      if (auf.key == 'tank' && t.isNotEmpty) {
        // Tank: Verteidigungseffekte plus viel Leben/Verteidigung
        final bester = t.reduce((x, y) => (rollen(x)['tank'] ?? 0) >= (rollen(y)['tank'] ?? 0) ? x : y);
        wert += auf.gewicht * ((rollen(bester)['tank'] ?? 0) / 100).clamp(0.0, 1.0);
        zuordnung.putIfAbsent(bester.id, () => []).add(auf.name);
        continue;
      }
      for (var i = 0; i < anbieter.length; i++) {
        final faktor = i == 0 ? 1.0 : (i < auf.anzahl ? 0.5 : 0.08);
        wert += auf.gewicht * faktor * tempoWert(anbieter[i].tempoId);
        if (i < auf.anzahl) zuordnung.putIfAbsent(anbieter[i].id, () => []).add(auf.name);
      }
    }
    return (wert: wert, max: max, zuordnung: zuordnung);
  }

  // ------------------------------------------------------------------------
  // Bewertung eines Teams
  // ------------------------------------------------------------------------
  double teamWert(List<Held> t, Modus m, {String? titanFarbe, List<Held> gegner = const []}) {
    if (t.isEmpty) return 0;
    if (m == Modus.gegner && gegner.isNotEmpty) {
      return _logit(t, gegner) + 0.5 * _aufgabenAnteil(t, Modus.angriff) + 0.1 * _kraftAnteil(t);
    }
    final aufgabe = _aufgabenAnteil(t, m);
    final kraftA = _kraftAnteil(t);
    final tempo = t.map((h) => tempoWert(h.tempoId)).reduce((x, y) => x + y) / t.length;

    var extra = 0.0;
    if (m == Modus.verteidigung) {
      final farben = t.map((h) => h.element).toSet().length;
      extra += farben >= 3 ? 0.04 : 0;
    }
    if (m == Modus.titan && titanFarbe != null) {
      // Farbvorteil ist beim Titan das Wichtigste (doppelter Steinschaden)
      final vorteil = t.map((h) => farbVorteil(h.element, titanFarbe)).reduce((x, y) => x + y) / t.length;
      extra += 0.35 * vorteil;
    }
    extra += harmonie(t, m).wert;
    // Wer sich selbst schwächt, ist nur mit gutem Grund im Team
    extra -= 0.02 * t.where((h) => h.effekte.contains('self_debuff')).length;
    // Zu viele langsame Helden im Angriff
    if (m != Modus.verteidigung) {
      final langsam = t.where((h) => h.tempoId == 'slow' || h.tempoId == 'very_slow').length;
      if (langsam >= 3) extra -= 0.05 * (langsam - 2);
    }
    final familien = <String, int>{};
    for (final h in t) {
      if (h.familie.isNotEmpty) familien[h.familie] = (familien[h.familie] ?? 0) + 1;
    }
    extra += familien.values.where((n) => n >= 2).length * 0.02;

    // Aufgaben zuerst, Stärke nur nachrangig
    return 0.60 * aufgabe + 0.25 * kraftA + 0.15 * tempo + extra;
  }

  /// Hauptrolle eines Helden – daran sieht man, ob ein Team ausgewogen ist
  static String hauptRolle(Held h) {
    final fx = h.effekte;
    bool hat(List<String> l) => l.any(fx.contains);
    final heilt = hat(_heilung) || hat(_reinigen);
    final flaeche = hat(_flaeche);
    final einzel = fx.contains('hit_single') && !flaeche;
    final stuetzt = hat(_vertRunter) || fx.contains('atk_up') || hat(_bannen) || hat(_manaKontrolle);
    if (hat(const ['taunt', 'mimic']) || (fx.contains('counter') && hat(const ['def_up', 'dmg_reduction']))) return 'tank';
    if (heilt && !flaeche && !einzel) return 'heiler';
    if (heilt && (flaeche || einzel)) return stuetzt ? 'unterstuetzer' : 'heiler';
    if (einzel) return stuetzt ? 'unterstuetzer' : 'sniper';
    if (flaeche) return stuetzt ? 'unterstuetzer' : 'flaeche';
    if (stuetzt) return 'unterstuetzer';
    return 'sonstiges';
  }

  static String rollenName(String r) => switch (r) {
        'tank' => 'Tank',
        'heiler' => tx('Heiler', 'Healer'),
        'sniper' => tx('Sniper (Einzelziel)', 'Sniper (single target)'),
        'flaeche' => tx('Flächenschaden', 'AoE damage'),
        'unterstuetzer' => tx('Unterstützer', 'Support'),
        _ => tx('Sonstiges', 'Other'),
      };

  /// Zu viele Helden derselben Rolle bringen nichts (4 Heiler, 4 Sniper …).
  /// Liefert einen Abzug und die Gründe.
  ({double wert, List<String> gruende}) harmonie(List<Held> t, Modus m) {
    final zaehler = <String, int>{};
    for (final h in t) {
      final r = hauptRolle(h);
      zaehler[r] = (zaehler[r] ?? 0) + 1;
    }
    final grenzen = switch (m) {
      Modus.verteidigung => {'heiler': 1, 'sniper': 2, 'flaeche': 3, 'tank': 1, 'unterstuetzer': 3, 'sonstiges': 1},
      Modus.titan => {'heiler': 1, 'sniper': 3, 'flaeche': 2, 'tank': 1, 'unterstuetzer': 3, 'sonstiges': 1},
      _ => {'heiler': 2, 'sniper': 2, 'flaeche': 3, 'tank': 1, 'unterstuetzer': 3, 'sonstiges': 1},
    };
    var wert = 0.0;
    final gruende = <String>[];
    zaehler.forEach((r, n) {
      final zuViel = n - (grenzen[r] ?? 2);
      if (zuViel > 0) {
        wert -= 0.09 * zuViel;
        gruende.add(tx('$n× ${rollenName(r)} – zu viele derselben Rolle', '$n× ${rollenName(r)} – too many of one role'));
      }
    });
    // Angriff braucht mindestens 2 echte Schadensquellen
    if (m != Modus.verteidigung) {
      final schaden = t.where((h) => h.effekte.any((e) => const ['hit_aoe', 'hit_three', 'hit_single'].contains(e))).length;
      if (schaden < 2 && t.length >= 4) {
        wert -= 0.08;
        gruende.add(tx('Zu wenig Schaden im Team', 'Not enough damage in the team'));
      }
    }
    // Helden ohne Aufgabe im Team
    final zuordnung = _aufgabenWert(t, m).zuordnung;
    final mitlaeufer = t.where((h) => !zuordnung.containsKey(h.id)).length;
    wert -= 0.04 * mitlaeufer;
    return (wert: wert, gruende: gruende);
  }

  double _aufgabenAnteil(List<Held> t, Modus m) {
    final w = _aufgabenWert(t, m);
    return w.max == 0 ? 0 : (w.wert / w.max).clamp(0.0, 1.0);
  }

  /// Stärke im Verhältnis zu den 5 stärksten Helden im Pool (0..1)
  double _kraftAnteil(List<Held> t) {
    final schnitt = t.map(kraft).reduce((x, y) => x + y) / t.length;
    final bezug = _poolSpitze ?? 1500;
    return (schnitt / bezug).clamp(0.0, 1.1).toDouble();
  }

  double? _poolSpitze;

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
    final fuerAufgaben = m == Modus.gegner ? Modus.angriff : m;
    schlecht.insertAll(0, harmonie(t, fuerAufgaben).gruende);
    final zuordnung = _aufgabenWert(t, fuerAufgaben).zuordnung;
    final aufgabenText = <String, String>{
      for (final h in t)
        h.id: (zuordnung[h.id] ?? const []).isEmpty ? rollenName(hauptRolle(h)) : zuordnung[h.id]!.join(' · '),
    };
    final helden = m == Modus.verteidigung ? aufstellen(t) : t;
    return TeamVorschlag(helden, teamWert(t, m, titanFarbe: titanFarbe, gegner: gegner),
        chance: ch,
        staerken: gut,
        schwaechen: schlecht,
        aufgaben: aufgabenText,
        truppen: truppenZuteilen(helden, fuerAufgaben));
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
    _poolSpitze = () {
      final k = liste.map(kraft).toList()..sort((x, y) => y.compareTo(x));
      final top = k.take(5).toList();
      return top.isEmpty ? 1500.0 : top.reduce((x, y) => x + y) / top.length;
    }();
    // Die 30 besten insgesamt plus je Aufgabe die 6 besten Anbieter – so fehlt kein Spezialist
    final auswahl = <Held>{...liste.take(30)};
    final fuerAufgaben = m == Modus.gegner ? Modus.angriff : m;
    for (final auf in aufgaben(fuerAufgaben)) {
      final anbieter = liste.where((h) => auf.effekte.any(h.effekte.contains)).toList()
        ..sort((x, y) => (kraft(y) * tempoWert(y.tempoId)).compareTo(kraft(x) * tempoWert(x.tempoId)));
      auswahl.addAll(anbieter.take(6));
    }
    final out = auswahl.toList()..sort((x, y) => bewertet[y]!.compareTo(bewertet[x]!));
    return out;
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

class Aufgabe {
  final String key;
  final String name;
  final List<String> effekte;
  final double gewicht;
  final int anzahl; // wie viele Helden für diese Aufgabe sinnvoll sind
  const Aufgabe(this.key, this.name, this.effekte, this.gewicht, this.anzahl);
}
