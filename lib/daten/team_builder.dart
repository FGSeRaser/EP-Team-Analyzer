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
import 'titan.dart';
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

  /// So spielt man das Team: Reihenfolge, Ziele, Tipps
  final List<String> plan;
  const TeamVorschlag(this.helden, this.wert,
      {this.chance,
      this.staerken = const [],
      this.schwaechen = const [],
      this.aufgaben = const {},
      this.truppen = const {},
      this.plan = const []});
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

  /// Zufall für „Neu würfeln“ – ohne Zufall kommt immer dasselbe beste Team
  final math.Random? zufall;

  /// Bereits gezeigte Teams (Basis-IDs) – neue Würfe sollen sich davon unterscheiden
  final List<Set<String>> schonGezeigt;

  TeamBuilder(this.a,
      {this.kraftVon = const {},
      this.gegnerKraft = const {},
      this.truppenInventar = const [],
      this.zufall,
      this.schonGezeigt = const [],
      this.titan});

  /// Titan mit Besonderheiten (für den Titan-Modus)
  final TitanInfo? titan;

  final Map<String, double> _rauschen = {};
  double _rauschenVon(Held h) => zufall == null ? 0 : _rauschen.putIfAbsent(h.basisId, () => zufall!.nextDouble() * 0.10);

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
      extra += _titanExtra(t).wert;
    }
    extra += harmonie(t, m).wert;
    extra += zusammenspiel(t, m).wert;
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

  /// Titan-Besonderheiten: Farb-Bonus, Reflektieren, Buffs/Debuffs entfernen, Titanjäger
  ({double wert, List<String> gut, List<String> schlecht}) _titanExtra(List<Held> t) {
    final ti = titan;
    var w = 0.0;
    final gut = <String>[], schlecht = <String>[];
    if (t.isEmpty) return (wert: 0.0, gut: gut, schlecht: schlecht);
    final jaeger = t.where((h) => h.familie == 'titan_hunter').toList();
    if (jaeger.isNotEmpty) {
      w += 0.03 * jaeger.length;
      gut.add(tx('${jaeger.map((h) => h.nameL).join(', ')}: Titanjäger – mehr Schaden gegen Titanen',
          '${jaeger.map((h) => h.nameL).join(', ')}: titan hunter – more damage vs titans'));
    }
    if (ti == null) return (wert: w, gut: gut, schlecht: schlecht);
    final heilt = _hat(t, _heilung);
    final schuetzt = _hat(t, _schutz);
    if (ti.hat('bonus') && ti.bonusFarbe != null) {
      final n = t.where((h) => h.element == ti.bonusFarbe).length;
      w += 0.15 * n / t.length;
      if (n > 0) {
        gut.add(tx('$n Helden in der Bonus-Farbe ${_farbName(ti.bonusFarbe!)}', '$n heroes in the bonus color ${_farbName(ti.bonusFarbe!)}'));
      }
    }
    if (ti.hat('reflekt') || ti.hat('hart') || ti.selten || ti.sterne >= 11) {
      final faktor = (ti.hat('reflekt') ? 1.0 : 0.0) + (ti.hat('hart') ? 1.0 : 0.0) + (ti.selten || ti.sterne >= 11 ? 0.5 : 0.0);
      if (heilt) {
        w += 0.04 * faktor;
      } else {
        w -= 0.05 * faktor;
        schlecht.add(tx('Keine Heilung – gegen diesen Titan riskant', 'No healing – risky against this titan'));
      }
      if (schuetzt) w += 0.02 * faktor;
    }
    final buffer = t.where((h) => h.effekte.any(const ['atk_up', 'crit_up', 'elem_dmg_up'].contains)).toList();
    final debuffer = t.where((h) => h.effekte.any(_vertRunter.contains)).toList();
    if (ti.hat('bannt')) {
      if (debuffer.isNotEmpty) w += 0.05;
      w -= 0.02 * buffer.where((h) => !debuffer.contains(h)).length;
      if (debuffer.isEmpty) {
        schlecht.add(tx('Titan entfernt Buffs, aber niemand senkt seine Verteidigung', 'Titan removes buffs, but nobody lowers its defense'));
      }
    }
    if (ti.hat('reinigt')) {
      if (buffer.isNotEmpty) w += 0.05;
      w -= 0.02 * debuffer.where((h) => !buffer.contains(h)).length;
      if (buffer.isEmpty) {
        schlecht.add(tx('Titan entfernt Debuffs, aber niemand verstärkt den eigenen Angriff', 'Titan removes debuffs, but nobody boosts your attack'));
      }
    }
    return (wert: w, gut: gut, schlecht: schlecht);
  }

  // ------------------------------------------------------------------------
  // Spielplan: in welcher Reihenfolge zünden, wen zuerst angreifen, Tipps
  // ------------------------------------------------------------------------

  /// Reihenfolge zum Zünden der Spezialfähigkeiten
  List<Held> zuendReihenfolge(List<Held> t, Modus m) {
    int prio(Held h) {
      final fx = h.effekte;
      if (m != Modus.titan && fx.any(_manaKontrolle.contains)) return 0;
      if (fx.any(_vertRunter.contains)) return 1;
      if (fx.any(const ['atk_up', 'crit_up', 'elem_dmg_up', 'mana_up', 'mana_gain'].contains)) return 2;
      if (fx.any(_treffer.contains) || fx.any(const ['dot', 'dot_poison', 'dot_burn', 'dot_bleed'].contains)) return 3;
      if (fx.any(_heilung.contains) || fx.any(_reinigen.contains)) return 4;
      return 3;
    }

    final out = [...t];
    out.sort((x, y) {
      final p = prio(x).compareTo(prio(y));
      if (p != 0) return p;
      // Bei Schadenshelden: der stärkste zuletzt (er profitiert von allen Buffs)
      if (prio(x) == 3) return kraft(x).compareTo(kraft(y));
      return tempoWert(y.tempoId).compareTo(tempoWert(x.tempoId));
    });
    return out;
  }

  String _warum(Held h, Modus m) {
    final fx = h.effekte;
    if (m != Modus.titan && fx.any(_manaKontrolle.contains)) return tx('bremst das Mana der Gegner', 'slows enemy mana');
    if (fx.any(_vertRunter.contains)) return tx('senkt die Verteidigung', 'lowers defense');
    if (fx.contains('atk_up')) return tx('erhöht euren Angriff', 'raises your attack');
    if (fx.contains('crit_up')) return tx('erhöht die Krit-Chance', 'raises crit chance');
    if (fx.contains('elem_dmg_up')) return tx('verstärkt den Elementschaden', 'boosts element damage');
    if (fx.any(const ['mana_up', 'mana_gain'].contains)) return tx('lädt die anderen schneller auf', 'charges the others faster');
    if (fx.any(_flaeche.contains)) return tx('Flächenschaden', 'AoE damage');
    if (fx.any(_treffer.contains)) return tx('Schaden', 'damage');
    if (fx.any(_heilung.contains)) return tx('heilt', 'heals');
    if (fx.any(_reinigen.contains)) return tx('reinigt', 'cleanses');
    return rollenName(hauptRolle(h));
  }

  List<String> spielplan(List<Held> t, Modus m, {List<Held> gegner = const []}) {
    if (t.isEmpty) return const [];
    final plan = <String>[];
    if (m == Modus.verteidigung) {
      if (t.length == 5) {
        plan.add(tx('Mitte (Tank): ${t[2].nameL} – bekommt die meisten Steine ab, deshalb der robusteste Held.',
            'Center (tank): ${t[2].nameL} – takes most tiles, so the sturdiest hero goes here.'));
        plan.add(tx('Flanken außen: ${t[0].nameL} und ${t[4].nameL} – werden seltener getroffen und laden ihre Spezialfähigkeit oft zuerst.',
            'Outer flanks: ${t[0].nameL} and ${t[4].nameL} – get hit less and often charge their special first.'));
        plan.add(tx('Flügel: ${t[1].nameL} und ${t[3].nameL} – stützen den Tank.', 'Wings: ${t[1].nameL} and ${t[3].nameL} – support the tank.'));
      }
      return plan;
    }
    final reihe = zuendReihenfolge(t, m);
    plan.add(tx('Zünd-Reihenfolge: ${reihe.map((h) => '${h.nameL} (${_warum(h, m)})').join(' → ')}',
        'Firing order: ${reihe.map((h) => '${h.nameL} (${_warum(h, m)})').join(' → ')}'));
    final heiler = t.where((h) => h.effekte.any(_heilung.contains)).toList();
    final reiniger = t.where((h) => h.effekte.any(_reinigen.contains)).toList();
    final banner = t.where((h) => h.effekte.any(_bannen.contains)).toList();

    if (m == Modus.titan) {
      final ti = titan;
      final farbe = ti?.farbe;
      if (farbe != null) {
        final stark = starkGegen(farbe);
        final n = t.where((h) => farbVorteil(h.element, farbe) == 1).length;
        if (stark != null) {
          plan.add(tx('Farbe: ${_farbName(stark)} ist stark gegen den ${_farbName(farbe)}-Titan (doppelter Steinschaden) – $n von ${t.length} Helden haben den Vorteil. Diese Steine bevorzugt kombinieren.',
              'Color: ${_farbName(stark)} is strong against the ${_farbName(farbe)} titan (double tile damage) – $n of ${t.length} heroes have it. Prefer matching these tiles.'));
        }
      }
      plan.add(tx('Auf den Schwachpunkt zielen: Trifft man ihn, ist der Titan betäubt und greift nicht an – genau dann die großen Spezialfähigkeiten zünden.',
          'Aim for the weak spot: a hit stuns the titan so it skips its attack – fire the big specials right then.'));
      if (t.any((h) => h.effekte.any(_vertRunter.contains)) || t.any((h) => h.effekte.contains('atk_up'))) {
        plan.add(tx('Buffs und „Verteidigung runter“ halten nur wenige Züge – die Schadenshelden direkt danach zünden.',
            'Buffs and "defense down" last only a few turns – fire the damage heroes right after.'));
      } else {
        plan.add(tx('Niemand senkt die Verteidigung oder erhöht den Angriff – Kampfgegenstände wie Banner (z. B. Titan-Banner) mitnehmen.',
            'Nobody lowers defense or raises attack – bring battle items like banners (e.g. Titan Banner).'));
      }
      if (heiler.isNotEmpty) {
        plan.add(tx('${heiler.first.nameL} heilt: erst zünden, nachdem der Titan zugeschlagen hat – nicht auf Vorrat.',
            '${heiler.first.nameL} heals: fire after the titan has hit – not in advance.'));
      }
      if (ti != null) {
        if (ti.hat('reflekt')) {
          plan.add(tx('Titan reflektiert Schaden: nicht alle Spezialfähigkeiten auf einmal, Heilung bereithalten.',
              'Titan reflects damage: don\'t fire every special at once, keep healing ready.'));
        }
        if (ti.hat('bannt')) {
          plan.add(tx('Titan entfernt Buffs: „Angriff hoch“ erst unmittelbar vor dem Schaden zünden.',
              'Titan removes buffs: fire "attack up" right before the damage.'));
        }
        if (ti.hat('reinigt')) {
          plan.add(tx('Titan entfernt Debuffs: „Verteidigung runter“ direkt vor den Schadenshelden.',
              'Titan removes debuffs: fire "defense down" right before the damage heroes.'));
        }
        if (ti.hat('bonus') && ti.bonusFarbe != null) {
          plan.add(tx('Farb-Bonus: Helden in ${_farbName(ti.bonusFarbe!)} machen mehr Schaden – deren Steine nicht verschwenden.',
              'Color bonus: ${_farbName(ti.bonusFarbe!)} heroes deal more damage – don\'t waste their tiles.'));
        }
      }
      plan.add(tx('Die Helden stehen im Team in dieser Reihenfolge (links → rechts), damit du beim Zünden nicht suchen musst.',
          'The heroes are lined up in this order (left → right) so you don\'t have to search while firing.'));
      return plan;
    }

    if (gegner.isNotEmpty) {
      // Wen zuerst ausschalten?
      double gefahr(Held g) {
        final fx = g.effekte;
        var w = 0.0;
        if (fx.any(const ['revive', 'self_revive'].contains)) w += 3;
        if (fx.any(_heilung.contains)) w += 2;
        if (fx.any(_manaKontrolle.contains)) w += 1.5;
        if (fx.any(_bannen.contains) && t.any((h) => h.effekte.any(const ['atk_up', 'def_up', 'crit_up'].contains))) w += 1.5;
        if (fx.any(_flaeche.contains)) w += 1;
        if (fx.contains('taunt')) w -= 1;
        w += tempoWert(g.tempoId) * 2;
        return w;
      }

      String grund(Held g) {
        final fx = g.effekte;
        final l = <String>[
          if (fx.any(const ['revive', 'self_revive'].contains)) tx('belebt wieder', 'revives'),
          if (fx.any(_heilung.contains)) tx('heilt', 'heals'),
          if (fx.any(_manaKontrolle.contains)) tx('bremst euer Mana', 'slows your mana'),
          if (fx.any(_bannen.contains)) tx('bannt eure Buffs', 'dispels your buffs'),
          if (fx.any(_flaeche.contains)) tx('Flächenschaden', 'AoE damage'),
          if (g.tempoId == 'fast' || g.tempoId == 'very_fast') tx('schnell', 'fast'),
        ];
        return l.isEmpty ? rollenName(hauptRolle(g)) : l.take(3).join(', ');
      }

      final ziele = [...gegner]..sort((x, y) => gefahr(y).compareTo(gefahr(x)));
      plan.add(tx('Zuerst ausschalten: ${ziele.take(2).map((g) => '${g.nameL} (${grund(g)})').join(', dann ')}.',
          'Take out first: ${ziele.take(2).map((g) => '${g.nameL} (${grund(g)})').join(', then ')}.'));
      final tank = gegner.length >= 3 ? gegner[2] : gegner.first;
      final gegenTank = t.where((h) => farbVorteil(h.element, tank.element) == 1).length;
      if (gegenTank >= 3) {
        plan.add(tx('$gegenTank Helden haben Farbvorteil gegen den Tank ${tank.nameL} – ihr könnt ihn direkt durchbrechen.',
            '$gegenTank heroes are strong against the tank ${tank.nameL} – you can break through directly.'));
      } else {
        plan.add(tx('Gegen den Tank ${tank.nameL} habt ihr kaum Farbvorteil – Steine lieber unter den Flanken kombinieren (Steine treffen den Gegner über ihrer Spalte).',
            'Little color advantage vs the tank ${tank.nameL} – match tiles under the flanks instead (tiles hit the enemy above their column).'));
      }
      final buffGegner = gegner.where((g) => g.effekte.any(const ['atk_up', 'def_up', 'dodge', 'dmg_reduction', 'counter'].contains)).toList();
      if (banner.isNotEmpty && buffGegner.isNotEmpty) {
        plan.add(tx('${banner.first.nameL} erst bannen, wenn ${buffGegner.first.nameL} seine Buffs gezündet hat.',
            'Fire ${banner.first.nameL}\'s dispel after ${buffGegner.first.nameL} has cast its buffs.'));
      }
      final leidGegner = gegner.where((g) => g.effekte.any(const ['def_down', 'atk_down', 'dot', 'dot_poison', 'dot_burn', 'mana_debuff', 'acc_down'].contains)).toList();
      if (reiniger.isNotEmpty && leidGegner.isNotEmpty) {
        plan.add(tx('${reiniger.first.nameL} aufheben, bis ${leidGegner.first.nameL} seine Leiden verteilt hat – dann reinigen.',
            'Save ${reiniger.first.nameL} until ${leidGegner.first.nameL} has applied its ailments – then cleanse.'));
      }
    } else {
      if (reiniger.isNotEmpty) {
        plan.add(tx('${reiniger.first.nameL} aufheben, bis ihr Leiden habt – dann reinigen.', 'Save ${reiniger.first.nameL} until you have ailments – then cleanse.'));
      }
      if (banner.isNotEmpty) {
        plan.add(tx('${banner.first.nameL} zünden, wenn der Gegner Buffs hat.', 'Fire ${banner.first.nameL} when the enemy has buffs.'));
      }
    }
    if (heiler.isNotEmpty) {
      plan.add(tx('${heiler.first.nameL} heilt – nach dem großen Schaden der Gegner zünden, nicht auf Vorrat.',
          '${heiler.first.nameL} heals – fire after the enemy\'s big hit, not in advance.'));
    }
    return plan;
  }

  static const _treffer = ['hit_aoe', 'hit_three', 'hit_single', 'hit_spread', 'hit_random', 'hit_chain', 'hit_edges', 'extra_attack'];

  /// Wie gut sich die Helden gegenseitig unterstützen: Verstärker brauchen
  /// Schadensmacher, Mana-Helfer brauchen langsame Helden, gleiche Buffs
  /// überschreiben sich im Spiel (sie stapeln nicht).
  ({double wert, List<String> gut, List<String> schlecht}) zusammenspiel(List<Held> t, Modus m) {
    var wert = 0.0;
    final gut = <String>[];
    final schlecht = <String>[];
    if (t.length < 3) return (wert: 0.0, gut: gut, schlecht: schlecht);
    List<Held> mit(List<String> fx) => t.where((h) => fx.any(h.effekte.contains)).toList();
    String namen(Iterable<Held> l) => l.map((h) => h.nameL).join(', ');
    final schadenMacher = mit(_treffer);

    // 1) Angriff hoch / Krit hoch verstärkt die Schadensmacher
    final booster = mit(const ['atk_up', 'crit_up']);
    if (m != Modus.verteidigung && booster.isNotEmpty) {
      final profitieren = schadenMacher.where((h) => !booster.contains(h)).toList();
      if (profitieren.length >= 2) {
        wert += 0.04;
        gut.add(tx('${booster.first.nameL} verstärkt den Schaden von ${namen(profitieren.take(3))}',
            '${booster.first.nameL} boosts the damage of ${namen(profitieren.take(3))}'));
      }
    }
    // 2) Verteidigung runter öffnet den Gegner für die Schadensmacher
    final oeffner = mit(_vertRunter);
    if (oeffner.isNotEmpty) {
      final profitieren = schadenMacher.where((h) => !oeffner.contains(h)).toList();
      if (profitieren.length >= 2) {
        wert += 0.04;
        gut.add(tx('${oeffner.first.nameL} senkt die Verteidigung – ${namen(profitieren.take(3))} treffen härter',
            '${oeffner.first.nameL} lowers defense – ${namen(profitieren.take(3))} hit harder'));
      }
    }
    // 3) Mana-Helfer machen langsame Helden schneller
    final manaHelfer = mit(const ['mana_up', 'mana_gain']);
    final langsam = t.where((h) => (h.tempoId == 'slow' || h.tempoId == 'very_slow') && !manaHelfer.contains(h)).toList();
    if (manaHelfer.isNotEmpty && langsam.isNotEmpty) {
      wert += 0.02 + 0.01 * math.min(langsam.length, 2);
      gut.add(tx('${manaHelfer.first.nameL} lädt die langsamen ${namen(langsam)} schneller auf',
          '${manaHelfer.first.nameL} charges the slow ${namen(langsam)} faster'));
    }
    // 4) Schaden über Zeit + „mehr Schaden erhalten“ / längere Leiden
    final dot = mit(const ['dot', 'dot_poison', 'dot_burn', 'dot_bleed', 'dot_water', 'dot_frost', 'dot_sand', 'dot_curse']);
    final dotHilfe = mit(const ['ailment_turns_up', 'dmg_taken_up']);
    if (dot.isNotEmpty && dotHilfe.any((h) => !dot.contains(h) || dot.length > 1)) {
      wert += 0.02;
      gut.add(tx('${namen(dotHilfe.take(1))} verstärkt den Schaden über Zeit von ${namen(dot.take(2))}',
          '${namen(dotHilfe.take(1))} amplifies the damage over time of ${namen(dot.take(2))}'));
    }
    // 5) Tank + Heiler halten zusammen (vor allem Verteidigung/Titan)
    final tanks = t.where((h) => hauptRolle(h) == 'tank').toList();
    final heiler = mit(_heilung);
    if (tanks.isNotEmpty && heiler.any((h) => !tanks.contains(h)) && m != Modus.titan) {
      wert += 0.02;
    }
    // 6) Farb-Stapel mit Element-Verstärkung (z. B. 3× Rot + „Feuerschaden hoch“)
    if (m == Modus.angriff || m == Modus.titan || m == Modus.gegner) {
      final farben = <String, int>{};
      for (final h in t) {
        farben[h.element] = (farben[h.element] ?? 0) + 1;
      }
      final stapel = farben.entries.where((e) => e.value >= 3).toList();
      if (stapel.isNotEmpty && mit(const ['elem_dmg_up', 'elem_def_down']).isNotEmpty) {
        wert += 0.03;
        gut.add(tx('Farb-Stapel: ${stapel.first.value}× ${_farbName(stapel.first.key)} mit Element-Verstärkung',
            'Color stack: ${stapel.first.value}× ${_farbName(stapel.first.key)} with element boost'));
      }
    }
    // 7) Gleiche Buffs/Debuffs überschreiben sich – doppelt bringt fast nichts
    for (final gruppe in const [
      ['atk_up'],
      ['def_down'],
      ['def_up'],
      ['mana_up'],
    ]) {
      final reine = t.where((h) {
        if (!gruppe.any(h.effekte.contains)) return false;
        // Nur zählen, wenn der Held sonst wenig mitbringt (reiner Buffer)
        return !h.effekte.any(_treffer.contains) || h.effekte.length <= 3;
      }).toList();
      if (reine.length >= 2) {
        wert -= 0.03 * (reine.length - 1);
        schlecht.add(tx('${namen(reine)} geben denselben Effekt – der überschreibt sich im Spiel',
            '${namen(reine)} give the same effect – it overwrites itself in the game'));
      }
    }
    return (wert: wert, gut: gut, schlecht: schlecht);
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
      final zugeteilt = truppenZuteilen(t, m);
      final bericht = a.team(truppenVon(db).teamMitTruppen(t, zugeteilt));
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
        final te = _titanExtra(t);
        gut.addAll(te.gut);
        schlecht.addAll(te.schlecht);
      }
    }
    final fuerAufgaben = m == Modus.gegner ? Modus.angriff : m;
    schlecht.insertAll(0, harmonie(t, fuerAufgaben).gruende);
    final zs = zusammenspiel(t, m);
    gut.insertAll(0, zs.gut);
    schlecht.addAll(zs.schlecht);
    final zuordnung = _aufgabenWert(t, fuerAufgaben).zuordnung;
    final aufgabenText = <String, String>{
      for (final h in t)
        h.id: (zuordnung[h.id] ?? const []).isEmpty ? rollenName(hauptRolle(h)) : zuordnung[h.id]!.join(' · '),
    };
    final helden = m == Modus.verteidigung ? aufstellen(t) : zuendReihenfolge(t, m);
    return TeamVorschlag(helden, teamWert(t, m, titanFarbe: titanFarbe, gegner: gegner),
        chance: ch,
        staerken: gut,
        schwaechen: schlecht,
        aufgaben: aufgabenText,
        truppen: truppenZuteilen(helden, fuerAufgaben),
        plan: spielplan(helden, m, gegner: gegner));
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
    double basis(List<Held> t) => teamWert(t, m, titanFarbe: titanFarbe, gegner: gegner);
    // Beim Würfeln: kleines Zufallsrauschen je Held und Abzug für Teams,
    // die einem schon gezeigten Team zu sehr ähneln – so kommen neue Builds,
    // die trotzdem gut zusammenpassen.
    double wert(List<Held> t) {
      var w = basis(t);
      if (zufall != null && t.isNotEmpty) w += t.map(_rauschenVon).reduce((x, y) => x + y) / t.length;
      if (schonGezeigt.isNotEmpty) {
        final ids = t.map((h) => h.basisId).toSet();
        final gleich = schonGezeigt.map((g) => g.intersection(ids).length).reduce(math.max);
        if (gleich >= 3) w -= 0.05 * (gleich - 2);
      }
      return w;
    }

    String schluessel(List<Held> t) => (t.map((h) => h.basisId).toList()..sort()).join('|');
    final verboten = {for (final g in schonGezeigt) (g.toList()..sort()).join('|')};
    final ergebnisse = <List<Held>>[];
    final startHelden = <Held>[];
    if (zufall != null) {
      // Zufällige Starthelden aus dem oberen Teil der Kandidaten
      final oben = kandidaten.take(math.max(12, anzahl * 4)).toList()..shuffle(zufall);
      startHelden.addAll(oben.take(anzahl * 3));
    } else {
      startHelden.addAll(kandidaten.take(anzahl * 2));
    }
    for (final start in startHelden) {
      final team = _suche(kandidaten, [start], wert);
      final k = schluessel(team);
      if (verboten.contains(k)) continue;
      if (ergebnisse.every((e) => schluessel(e) != k)) ergebnisse.add(team);
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
      final v = baue(rest, Modus.krieg, anzahl: zufall == null ? 1 : 2);
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
