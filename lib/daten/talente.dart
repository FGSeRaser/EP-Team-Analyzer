// E&P Team-Analyzer – Talent-Raster (Embleme) und Empfehlung je Held, Position und Einsatz
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Raster aller 10 Klassen aus HeroPlan (GPL-3.0). An jeder Gabelung wählt man im Spiel
// die linke oder rechte Seite – die App bewertet beide Seiten mit Gewichten, die zum
// Helden (Rolle, Tempo), zur Position und zum Einsatz passen.

import 'dart:convert';

import 'datenbank.dart';
import 'live_daten.dart';
import 'sprache.dart';
import 'team_builder.dart';
import 'werte.dart';

class TalentKnoten {
  final String typ; // atk, def, hp, mana, crit, heal, talent
  final int wert;
  final bool prozent;
  final int nr;
  const TalentKnoten(this.typ, this.wert, this.prozent, this.nr);

  factory TalentKnoten.ausJson(Map<String, dynamic> j) =>
      TalentKnoten(j['t'] as String, (j['v'] as num?)?.toInt() ?? 0, j['p'] == true, (j['n'] as num).toInt());

  String get name => switch (typ) {
        'atk' => tx('Angriff', 'Attack'),
        'def' => tx('Verteidigung', 'Defense'),
        'hp' => tx('Leben', 'Health'),
        'mana' => 'Mana',
        'crit' => tx('Krit', 'Crit'),
        'heal' => tx('Heilung', 'Healing'),
        _ => tx('Klassen-Talent', 'Class talent'),
      };

  String get text => typ == 'talent' ? name : '$name +$wert${prozent ? ' %' : ''}';
}

class TalentGabel {
  final List<TalentKnoten> links, rechts;
  const TalentGabel(this.links, this.rechts);
  int get ersterKnoten => links.first.nr;
  bool get meister => ersterKnoten > 20;
}

class TalentRaster {
  final List<TalentKnoten> pflicht;
  final List<TalentGabel> gabeln;
  const TalentRaster(this.pflicht, this.gabeln);

  static Map<String, TalentRaster>? _cache;

  static Map<String, TalentRaster> ausJson(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final out = <String, TalentRaster>{};
    (j['klassen'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      List<TalentKnoten> liste(dynamic l) =>
          [for (final x in l as List) TalentKnoten.ausJson(x as Map<String, dynamic>)];
      out[k] = TalentRaster(
        liste(m['pflicht']),
        [for (final g in m['gabel'] as List) TalentGabel(liste(g['l']), liste(g['r']))],
      );
    });
    return out;
  }

  static bool _hook = false;
  static Future<Map<String, TalentRaster>> laden() async {
    if (!_hook) {
      _hook = true;
      LiveDaten.beimWechsel(() => _cache = null);
    }
    return _cache ??= ausJson(await LiveDaten.text('talente.json'));
  }
}

/// Wofür der Held eingesetzt wird
enum Einsatz { verteidigung, angriff, titan }

String einsatzName(Einsatz e) => switch (e) {
      Einsatz.verteidigung => tx('Verteidigung', 'Defense'),
      Einsatz.angriff => tx('Angriff & Krieg', 'Attack & war'),
      Einsatz.titan => 'Titan',
    };

/// Position in der Verteidigung: flanke, fluegel, tank
String positionName(String p) => switch (p) {
      'tank' => tx('Tank (Mitte)', 'Tank (center)'),
      'fluegel' => tx('Flügel', 'Wing'),
      _ => tx('Flanke', 'Flank'),
    };

class TalentGewichte {
  final Map<String, double> w; // atk, def, hp, mana, crit, heal
  final List<String> gruende;
  const TalentGewichte(this.w, this.gruende);
  double operator [](String k) => w[k] ?? 0;

  /// Reihenfolge Angriff/Verteidigung/Leben, z. B. "Verteidigung > Leben > Angriff"
  String get reihenfolge {
    final l = ['atk', 'def', 'hp']..sort((a, b) => this[b].compareTo(this[a]));
    return l.map((k) => TalentKnoten(k, 0, false, 0).name).join(' > ');
  }
}

class GabelEmpfehlung {
  final TalentGabel gabel;
  final bool links;
  final double wertLinks, wertRechts;
  final String grund;
  const GabelEmpfehlung(this.gabel, this.links, this.wertLinks, this.wertRechts, this.grund);
  List<TalentKnoten> get gewaehlt => links ? gabel.links : gabel.rechts;

  /// Beide Seiten fast gleich gut
  bool get knapp {
    final mx = wertLinks > wertRechts ? wertLinks : wertRechts;
    return mx <= 0 || (wertLinks - wertRechts).abs() / mx < 0.08;
  }
}

class PositionsTipp {
  final String position;
  final double wert;
  final List<String> gruende;
  const PositionsTipp(this.position, this.wert, this.gruende);
}

class TalentEmpfehlung {
  final TalentGewichte gewichte;
  final List<GabelEmpfehlung> gabeln;
  final Map<String, num> summe; // atk/def/hp als Punkte, mana/crit/heal in %
  final List<PositionsTipp> positionen; // beste zuerst (nur Verteidigung)
  const TalentEmpfehlung(this.gewichte, this.gabeln, this.summe, this.positionen);
}

class TalentAnalyse {
  static const _schaden = ['hit_aoe', 'hit_three', 'hit_single', 'hit_spread', 'hit_random', 'hit_chain', 'hit_edges', 'extra_attack'];
  static const _dot = ['dot', 'dot_poison', 'dot_burn', 'dot_bleed', 'dot_water', 'dot_frost', 'dot_sand', 'dot_curse'];
  static const _heilt = ['heal', 'heal_ot', 'health_boost', 'revive'];
  static const _tankFx = ['taunt', 'mimic', 'def_up', 'dmg_reduction', 'counter', 'dodge'];
  static const _stuetzt = ['atk_up', 'def_down', 'elem_def_down', 'dmg_taken_up', 'mana_up', 'mana_gain', 'dispel', 'mana_debuff'];

  static bool _hat(Held h, List<String> l) => l.any(h.effekte.contains);

  /// Gewichte für Angriff/Verteidigung/Leben/Mana/Krit/Heilung
  static TalentGewichte gewichte(Held h, Einsatz e, String position) {
    final w = <String, double>{};
    final gruende = <String>[];
    final rolle = TeamBuilder.hauptRolle(h);
    final machtSchaden = _hat(h, _schaden) || _hat(h, _dot);

    switch (e) {
      case Einsatz.verteidigung:
        switch (position) {
          case 'tank':
            w.addAll({'atk': 0.12, 'def': 0.44, 'hp': 0.44});
            gruende.add(tx('Der Tank bekommt die meisten Steine ab – Verteidigung und Leben halten ihn am Leben.',
                'The tank takes most tiles – defense and health keep it alive.'));
          case 'fluegel':
            w.addAll({'atk': 0.25, 'def': 0.35, 'hp': 0.40});
            gruende.add(tx('Flügel werden oft mitgetroffen (Flächenschaden) – Überleben zählt, Schaden etwas weniger.',
                'Wings are often hit by AoE – survival counts, damage a bit less.'));
          default:
            w.addAll({'atk': 0.42, 'def': 0.26, 'hp': 0.32});
            gruende.add(tx('Flanken werden seltener getroffen und zünden oft zuerst – hier zählt der Schaden.',
                'Flanks get hit less and often fire first – damage counts here.'));
        }
      case Einsatz.angriff:
        w.addAll({'atk': 0.45, 'def': 0.25, 'hp': 0.30});
        gruende.add(tx('Im Angriff zählt Schaden, aber der Held muss die gegnerischen Spezialfähigkeiten überleben.',
            'In attack damage counts, but the hero has to survive enemy specials.'));
      case Einsatz.titan:
        w.addAll({'atk': 0.70, 'def': 0.10, 'hp': 0.20});
        gruende.add(tx('Gegen Titanen zählt fast nur der Schaden – jeder Angriffspunkt ist mehr Titan-Schaden.',
            'Against titans almost only damage counts – every attack point is more titan damage.'));
    }

    // Rolle des Helden
    if (!machtSchaden && (rolle == 'heiler' || rolle == 'unterstuetzer' || rolle == 'tank')) {
      final weg = (w['atk']! * 0.6);
      w['atk'] = w['atk']! - weg;
      w['def'] = w['def']! + weg * 0.45;
      w['hp'] = w['hp']! + weg * 0.55;
      gruende.add(tx('${h.nameL} macht kaum direkten Schaden – Angriff bringt wenig, lieber Überleben.',
          '${h.nameL} deals little direct damage – attack adds little, survival is better.'));
    } else if (machtSchaden && (rolle == 'sniper' || rolle == 'flaeche')) {
      w['atk'] = w['atk']! + 0.08;
      w['def'] = w['def']! - 0.04;
      w['hp'] = w['hp']! - 0.04;
      gruende.add(tx('${h.nameL} ist ein Schadensmacher – Angriff wird stärker gewichtet.',
          '${h.nameL} is a damage dealer – attack is weighted higher.'));
    }
    if (_hat(h, _tankFx) && e == Einsatz.verteidigung && position != 'flanke') {
      w['def'] = w['def']! + 0.04;
      w['hp'] = w['hp']! + 0.04;
      w['atk'] = (w['atk']! - 0.08).clamp(0.02, 1.0);
    }
    if (_hat(h, _dot) && e != Einsatz.verteidigung) {
      gruende.add(tx('Schaden über Zeit hängt am Angriff – Angriff lohnt sich doppelt.', 'Damage over time scales with attack – attack pays off twice.'));
    }

    // Mana: langsame Helden profitieren am meisten
    final tempo = h.tempoId;
    w['mana'] = switch (tempo) {
      'very_fast' => 0.05,
      'fast' => 0.12,
      'average' => 0.26,
      'slow' => 0.30,
      'very_slow' => 0.30,
      _ => 0.18,
    };
    if (e == Einsatz.titan) w['mana'] = w['mana']! * 1.2;
    if (tempo == 'average' || tempo == 'slow' || tempo == 'very_slow') {
      gruende.add(tx('${h.nameL} lädt nicht schnell auf – Mana-Knoten sind besonders wertvoll.',
          '${h.nameL} doesn\'t charge fast – mana nodes are especially valuable.'));
    }
    w['crit'] = machtSchaden && e != Einsatz.verteidigung ? (e == Einsatz.titan ? 0.20 : 0.12) : 0.04;
    w['heal'] = e == Einsatz.verteidigung && position == 'tank' ? 0.06 : 0.03;
    return TalentGewichte(w, gruende);
  }

  /// Wert eines Knotens: Prozent-Zugewinn am eigenen Wert × Gewicht
  static double knotenWert(TalentKnoten k, TalentGewichte g, Map<String, int> basis) {
    switch (k.typ) {
      case 'atk':
      case 'def':
      case 'hp':
        final b = (basis[k.typ] ?? 1).clamp(1, 1 << 30);
        final prozent = k.prozent ? k.wert.toDouble() : k.wert * 100 / b;
        return prozent * g[k.typ];
      case 'mana':
        return k.wert * 2.5 * g['mana'];
      case 'crit':
        return k.wert * 1.5 * g['crit'];
      case 'heal':
        return k.wert * 0.5 * g['heal'];
      default:
        return 0;
    }
  }

  static int _punkte(TalentKnoten k, Map<String, int> basis) =>
      k.prozent ? ((basis[k.typ] ?? 0) * k.wert / 100).floor() : k.wert;

  static TalentEmpfehlung empfehlen(
    Held h,
    TalentRaster raster,
    Stand werte,
    Einsatz e,
    String position, {
    bool meister = true,
  }) {
    final basis = {'atk': werte.angriff, 'def': werte.verteidigung, 'hp': werte.leben};
    final g = gewichte(h, e, position);
    final gabeln = <GabelEmpfehlung>[];
    final summe = <String, num>{'atk': 0, 'def': 0, 'hp': 0, 'mana': 0, 'crit': 0, 'heal': 0};

    void zaehle(TalentKnoten k) {
      if (k.typ == 'talent') return;
      if (k.typ == 'atk' || k.typ == 'def' || k.typ == 'hp') {
        summe[k.typ] = summe[k.typ]! + _punkte(k, basis);
      } else {
        summe[k.typ] = summe[k.typ]! + k.wert;
      }
    }

    for (final k in raster.pflicht) {
      if (k.nr > 20 && !meister) continue;
      zaehle(k);
    }
    for (final gb in raster.gabeln) {
      if (gb.meister && !meister) continue;
      final wl = gb.links.fold(0.0, (a, k) => a + knotenWert(k, g, basis));
      final wr = gb.rechts.fold(0.0, (a, k) => a + knotenWert(k, g, basis));
      final links = wl >= wr;
      final seite = links ? gb.links : gb.rechts;
      // Grund: der Knoten, der den Unterschied macht
      final besterKnoten = [...seite]..sort((a, b) => knotenWert(b, g, basis).compareTo(knotenWert(a, g, basis)));
      final grund = besterKnoten.isEmpty ? '' : besterKnoten.first.text;
      gabeln.add(GabelEmpfehlung(gb, links, wl, wr, grund));
      seite.forEach(zaehle);
    }
    return TalentEmpfehlung(g, gabeln, summe, e == Einsatz.verteidigung ? positionsTipps(h, werte) : const []);
  }

  /// Wie gut passt der Held auf Tank, Flügel oder Flanke? Beste zuerst.
  static List<PositionsTipp> positionsTipps(Held h, Stand werte) {
    final rolle = TeamBuilder.hauptRolle(h);
    final tempo = h.tempoId;
    final schnell = tempo == 'fast' || tempo == 'very_fast';
    final langsam = tempo == 'slow' || tempo == 'very_slow';
    // Wie "dick" ist der Held? Verteidigung + Leben im Verhältnis zum Angriff
    final dicke = (werte.verteidigung + werte.leben / 2) / (werte.angriff <= 0 ? 1 : werte.angriff);

    final tank = <String>[], fluegel = <String>[], flanke = <String>[];
    var wt = 0.0, wf = 0.0, wl = 0.0;

    if (rolle == 'tank') {
      wt += 2;
      tank.add(tx('hat Tank-Fähigkeiten (z. B. Spott, Konter, Schutz)', 'has tank skills (taunt, counter, protection)'));
    }
    if (_hat(h, const ['def_up', 'dmg_reduction', 'dodge', 'special_def_up', 'share_damage'])) {
      wt += 0.8;
      fluegel.add(tx('schützt sich oder das Team', 'protects itself or the team'));
      wl += 0.3;
    }
    if (dicke >= 1.5) {
      wt += 1.2;
      tank.add(tx('hohe Verteidigung und viel Leben', 'high defense and lots of health'));
    } else if (dicke < 1.15) {
      wt -= 0.8;
      flanke.add(tx('eher wenig Verteidigung – hält als Tank nicht lange', 'rather low defense – won\'t last as tank'));
      wf += 0.4;
    }
    if (_hat(h, _heilt) || h.effekte.contains('cleanse')) {
      wl += 1.4;
      fluegel.add(tx('heilt/reinigt – vom Flügel aus erreicht das das ganze Team', 'heals/cleanses – from the wing it reaches the whole team'));
    }
    if (_hat(h, _stuetzt)) {
      wl += 0.6;
      fluegel.add(tx('unterstützt das Team', 'supports the team'));
    }
    if (_hat(h, const ['hit_aoe', 'hit_three', 'hit_single', 'mana_debuff', 'dispel'])) {
      wf += 1.0;
      flanke.add(tx('Schaden/Störung, die früh zünden soll', 'damage/disruption that should fire early'));
    }
    if (schnell) {
      wf += 1.2;
      flanke.add(tx('schnelles Mana – auf der Flanke zündet er oft zuerst', 'fast mana – on the flank it often fires first'));
      wt += 0.3;
    }
    if (langsam) {
      wf -= 0.8;
      wt += 0.2;
      fluegel.add(tx('langsames Mana – auf der Flanke käme er zu spät', 'slow mana – on the flank it would come too late'));
    }
    final l = [PositionsTipp('tank', wt, tank), PositionsTipp('fluegel', wl, fluegel), PositionsTipp('flanke', wf, flanke)]
      ..sort((a, b) => b.wert.compareTo(a.wert));
    return l;
  }
}
