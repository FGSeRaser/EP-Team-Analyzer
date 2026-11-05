// E&P Team-Analyzer – Truppen und welche zu welchem Helden passen
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Regeln aus dem Spiel:
//  - Ein Held benutzt immer eine Truppe SEINER Farbe.
//  - Legendäre Truppen haben eine Haupt- und Nebenklasse. Passt die Klasse des
//    Helden, bekommt er die vollen Boni und das Truppen-Passiv.
//  - Mana-/Magie-/Styx-Truppen laden die Spezialfähigkeit schneller (Angriff, Krieg).
//  - Krit-Truppen geben mehr Verteidigung und kritische Treffer (Verteidigung, Titan).

import 'analyse.dart';
import 'datenbank.dart';
import 'sprache.dart';
import 'team_builder.dart';
import 'truppen_besitz.dart';

class TruppenPassiv {
  final String key, de, en;
  final List<String> rollen;
  const TruppenPassiv(this.key, this.de, this.en, this.rollen);
  String get label => tx(de, en);
}

class LegTruppe {
  final String name;
  final String klasse1, klasse2;
  final String passiv;
  const LegTruppe(this.name, this.klasse1, this.klasse2, this.passiv);
}

class EpTruppe {
  final String id, de, en, textDe, textEn;
  final List<List<int>> mana, krit, umgehen; // [Level, Prozent]
  final Map<String, String> namen; // je Farbe
  final List<String> modi;
  const EpTruppe({
    required this.id,
    required this.de,
    required this.en,
    required this.textDe,
    required this.textEn,
    this.mana = const [],
    this.krit = const [],
    this.umgehen = const [],
    this.namen = const {},
    this.modi = const [],
  });
  String get label => tx(de, en);
  String get text => tx(textDe, textEn);
  int get maxMana => mana.isEmpty ? 0 : mana.last[1];
}

class TruppenEmpfehlung {
  final String titel;
  final String grund;
  final int wert; // 0..100 zum Sortieren
  final LegTruppe? legendaer;
  final EpTruppe? episch;
  const TruppenEmpfehlung(this.titel, this.grund, this.wert, {this.legendaer, this.episch});
}

class TruppenWissen {
  final Map<String, TruppenPassiv> passive;
  final List<LegTruppe> legendaer;
  final List<EpTruppe> episch;
  final Map<String, List<List<int>>> manaSchwellen;
  final Map<String, Map<String, String>> klassen;

  TruppenWissen._(this.passive, this.legendaer, this.episch, this.manaSchwellen, this.klassen);

  factory TruppenWissen.aus(Map<String, dynamic> roh) {
    List<List<int>> stufen(dynamic x) =>
        [for (final e in (x as List? ?? const [])) [for (final v in e as List) (v as num).toInt()]];
    final passive = <String, TruppenPassiv>{};
    (roh['passive'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      passive[k] = TruppenPassiv(k, m['de'] as String, m['en'] as String, List<String>.from(m['rollen'] as List));
    });
    final leg = [
      for (final x in (roh['legendaer'] as List? ?? const []))
        LegTruppe((x as Map)['name'] as String, x['k1'] as String, x['k2'] as String, x['p'] as String),
    ];
    final ep = [
      for (final x in (roh['episch'] as List? ?? const []))
        EpTruppe(
          id: (x as Map)['id'] as String,
          de: x['de'] as String,
          en: x['en'] as String,
          textDe: x['text_de'] as String,
          textEn: x['text_en'] as String,
          mana: stufen(x['mana']),
          krit: stufen(x['krit']),
          umgehen: stufen(x['umgehen']),
          namen: Map<String, String>.from(x['namen'] as Map? ?? const {}),
          modi: List<String>.from(x['modi'] as List? ?? const []),
        ),
    ];
    final schwellen = <String, List<List<int>>>{};
    (roh['manaSchwellen'] as Map<String, dynamic>? ?? const {}).forEach((k, v) => schwellen[k] = stufen(v));
    final klassen = <String, Map<String, String>>{};
    (roh['klassen'] as Map<String, dynamic>? ?? const {})
        .forEach((k, v) => klassen[k] = Map<String, String>.from(v as Map));
    return TruppenWissen._(passive, leg, ep, schwellen, klassen);
  }

  String klasseName(String key) => klassen[key]?[Sprache.en ? 'en' : 'de'] ?? key;
  EpTruppe? epischNach(String id) {
    for (final e in episch) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Legendäre Truppen, die zur Klasse des Helden passen – bestes Passiv für seine Rolle zuerst
  List<TruppenEmpfehlung> legendaerFuer(Held h, Analyse a) {
    final rollen = a.rollenWerte(h);
    final out = <TruppenEmpfehlung>[];
    for (final t in legendaer) {
      final haupt = t.klasse1 == h.klasseKey;
      final neben = t.klasse2 == h.klasseKey;
      if (!haupt && !neben) continue;
      final p = passive[t.passiv];
      var rolle = 0;
      String? besteRolle;
      for (final r in p?.rollen ?? const <String>[]) {
        final w = rollen[r] ?? 0;
        if (w > rolle) {
          rolle = w;
          besteRolle = r;
        }
      }
      final wert = (haupt ? 40 : 20) + (rolle * 0.6).round();
      final rollenName = besteRolle == null ? '' : (a.db.rollen[besteRolle]?.label ?? besteRolle);
      out.add(TruppenEmpfehlung(
        t.name,
        '${haupt ? tx('Hauptklasse', 'Primary class') : tx('Nebenklasse', 'Secondary class')} '
        '${klasseName(h.klasseKey)} · ${p?.label ?? t.passiv}'
        '${rollenName.isEmpty ? '' : ' · ${tx('passt zu', 'fits')} $rollenName'}',
        wert,
        legendaer: t,
      ));
    }
    out.sort((x, y) => y.wert.compareTo(x.wert));
    return out;
  }

  /// Epische Truppe je Spielmodus
  List<MapEntry<String, List<TruppenEmpfehlung>>> epischFuer(Held h) {
    final langsam = const ['slow', 'very_slow', 'average'].contains(h.tempoId);
    final schnell = const ['fast', 'very_fast'].contains(h.tempoId);
    TruppenEmpfehlung e(String id, String grund, int wert) {
      final t = epischNach(id);
      final eigenerName = t?.namen[h.element];
      return TruppenEmpfehlung(
        '${t?.label ?? id}${eigenerName == null ? '' : ' – $eigenerName'}',
        grund,
        wert,
        episch: t,
      );
    }

    final angriff = <TruppenEmpfehlung>[
      if (langsam) ...[
        e('magie', tx('Größter Mana-Bonus – wichtig bei Tempo „${h.tempoL}“', 'Biggest mana bonus – key at speed "${h.tempoL}"'), 95),
        e('styx', tx('Viel Mana plus Verteidigung umgehen', 'Lots of mana plus bypassing defense'), 90),
        e('mana', tx('Leicht zu bekommen, +15 % Mana', 'Easy to get, +15% mana'), 80),
      ] else if (schnell) ...[
        e('styx', tx('Schneller Held wird noch schneller und umgeht Boni', 'Fast hero gets faster and bypasses buffs'), 92),
        e('ninja', tx('Mehr Angriff und Umgehen – Mana ist bei schnellen Helden weniger wichtig', 'More attack and bypass – mana matters less for fast heroes'), 85),
        e('mana', tx('Reicht für die nächste Mana-Schwelle', 'Reaches the next mana breakpoint'), 80),
      ] else ...[
        e('mana', tx('Besonderes Mana-Tempo: Mana-Bonus hilft beim Aufladen', 'Special mana speed: mana bonus helps charging'), 85),
        e('magie', tx('Noch mehr Mana', 'Even more mana'), 84),
      ],
    ];
    final verteidigung = <TruppenEmpfehlung>[
      e('krit', tx('Mehr Verteidigung und kritische Treffer', 'More defense and critical hits'), 90),
      if (langsam) e('mana', tx('Langsame Verteidiger kommen sonst kaum zum Zug', 'Slow defenders rarely fire otherwise'), 70),
    ];
    final titan = <TruppenEmpfehlung>[
      e('krit', tx('Kritische Treffer verdoppeln den Steinschaden', 'Critical hits double tile damage'), 90),
      e('ninja', tx('Höchster Angriff für Steinschaden', 'Highest attack for tile damage'), 80),
    ];
    return [
      MapEntry(tx('Angriff & Krieg', 'Attack & war'), angriff),
      MapEntry(tx('Verteidigung', 'Defense'), verteidigung),
      MapEntry('Titan', titan),
    ];
  }

  /// Wie gut passt eine eigene Truppe zu diesem Helden im Modus? (höher = besser)
  double truppenWert(EigeneTruppe t, Held h, Modus m, Map<String, int> rollen) {
    final angriff = m == Modus.angriff || m == Modus.krieg || m == Modus.gegner;
    // Mana hilft langsamen Helden viel, sehr schnellen kaum
    final manaGewicht = switch (h.tempoId) {
      'very_slow' || 'slow' => 1.0,
      'average' => 0.85,
      'fast' => 0.6,
      'very_fast' => 0.35,
      _ => 0.8,
    };
    var w = 0.0;
    switch (t.typ) {
      case 'leg':
        final leg = legendaer.where((l) => l.name == t.legName).toList();
        if (leg.isNotEmpty) {
          final l = leg.first;
          w += l.klasse1 == h.klasseKey ? 22 : (l.klasse2 == h.klasseKey ? 16 : 6);
          final p = passive[l.passiv];
          var rolle = 0;
          for (final r in p?.rollen ?? const <String>[]) {
            final v = rollen[r] ?? 0;
            if (v > rolle) rolle = v;
          }
          w += rolle / 10;
        } else {
          w += 10;
        }
        w += t.level / 4;
      case 'normal':
        w += t.sterne * 2 + t.level / 6;
      default:
        w += 8 + t.level / 6;
        if (angriff) {
          w += t.manaProzent(this) * manaGewicht;
          w += t.umgehenProzent(this) * 0.5; // Styx/Ninja umgehen Boni
          if (t.typ == 'ninja') w += 3;
        } else {
          w += t.kritProzent(this) * 1.2;
          if (t.typ == 'krit') w += 6;
          if (m == Modus.titan && t.typ == 'ninja') w += 5;
          if (m == Modus.verteidigung) w += t.manaProzent(this) * 0.3 * manaGewicht;
        }
    }
    return w;
  }

  /// Was eine Truppe dem Helden im Kampf gibt – als Effekte für die Analyse
  ({Set<String> effekte, Map<String, double> immun, List<String> texte}) truppenEffekte(EigeneTruppe t, Held h) {
    final fx = <String>{};
    final im = <String, double>{};
    final texte = <String>[];
    final mana = t.manaProzent(this);
    final krit = t.kritProzent(this);
    final umgehen = t.umgehenProzent(this);
    if (mana > 0) texte.add('Mana +$mana %');
    if (krit > 0) {
      fx.add('crit_up');
      texte.add('${tx('Krit', 'Crit')} $krit %');
    }
    if (umgehen > 0) {
      fx.add('bypass');
      texte.add(tx('$umgehen % Boni umgehen', '$umgehen% bypass buffs'));
    }
    if (t.typ == 'leg') {
      final l = legendaer.where((x) => x.name == t.legName).toList();
      if (l.isNotEmpty) {
        final passt = l.first.klasse1 == h.klasseKey || l.first.klasse2 == h.klasseKey;
        final p = passive[l.first.passiv];
        if (!passt) {
          texte.add(tx('Klasse passt nicht – kein Truppen-Passiv', 'Class does not match – no troop passive'));
        } else {
          texte.add(p?.label ?? l.first.passiv);
          switch (l.first.passiv) {
            case 'crit':
              fx.add('crit_up');
            case 'atk_add':
              fx.add('atk_up');
            case 'def_add':
              fx.add('def_up');
            case 'atk_red':
              fx.add('atk_down');
            case 'def_red':
              fx.add('def_down');
            case 'ailment_dmg':
              im['dot'] = 0.5;
            case 'resist':
              im['ailments'] = 0.35;
            case 'special_dmg':
              fx.add('elem_dmg_up');
            case 'special_def':
              fx.add('special_def_up');
            case 'heal_extra':
              fx.add('heal_up');
          }
        }
      }
    }
    return (effekte: fx, immun: im, texte: texte);
  }

  /// Team mit eingerechneten Truppen (für die Analyse)
  List<Held> teamMitTruppen(List<Held> team, Map<String, EigeneTruppe> truppen) => [
        for (final h in team)
          if (truppen[h.id] == null)
            h
          else
            () {
              final e = truppenEffekte(truppen[h.id]!, h);
              return h.mitZusatz(effekte: e.effekte, immun: e.immun);
            }(),
      ];

  /// Steine bis zur Spezialfähigkeit mit diesem Mana-Bonus (null, wenn unbekannt)
  int? steine(Held h, int manaProzent) {
    final s = manaSchwellen[h.tempoId];
    if (s == null || s.isEmpty) return null;
    var steine = s.first[1];
    for (final e in s) {
      if (manaProzent >= e[0]) steine = e[1];
    }
    return steine;
  }

  /// Mana-Schwellen-Hinweis: wie viel Mana-Bonus für einen Stein weniger
  String? manaHinweis(Held h) {
    final s = manaSchwellen[h.tempoId];
    if (s == null || s.length < 2) return null;
    final basis = s.first[1];
    final naechste = s[1];
    return tx(
      '${h.tempoL}: $basis Steine · ab +${naechste[0]} % Mana nur ${naechste[1]} Steine '
          '(zählt zusammen: Truppe, Kostüm +5 %, Embleme +2/4 %)',
      '${h.tempoL}: $basis tiles · from +${naechste[0]}% mana only ${naechste[1]} tiles '
          '(adds up: troop, costume +5%, emblems +2/4%)',
    );
  }
}

final Expando<TruppenWissen> _cache = Expando<TruppenWissen>();

/// Truppenwissen der Datenbank (einmal aufgebaut, dann gemerkt)
TruppenWissen truppenVon(Datenbank db) => _cache[db] ??= TruppenWissen.aus(db.truppenRoh);
