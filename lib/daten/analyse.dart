// E&P Team-Analyzer – Analyse-Logik (Stärken, Schwächen, Konter)
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'datenbank.dart';

/// Bedrohungen, die beim Team-Check immer geprüft werden
const List<String> wichtigeBedrohungen = [
  'mana_debuff',
  'mana_cut',
  'special_block',
  'insanity',
  'dot',
  'def_down',
  'atk_down',
  'acc_down',
  'heal_block',
  'buff_block',
  'cleanse_block',
  'dispel',
  'taunt',
  'counter',
  'def_up',
  'dodge',
  'mimic',
  'minions',
  'fiend',
  'revive',
  'heal',
];

class Analyse {
  final Datenbank db;
  const Analyse(this.db);

  /// Wie gut ist der Held selbst gegen eine Bedrohung geschützt (0..1)?
  double schutz(Held h, String bedrohung) {
    double s = h.immun[bedrohung] ?? 0;
    if (bedrohung.startsWith('dot_')) {
      s = _max(s, h.immun['dot'] ?? 0);
    }
    if (db.leidenBedrohungen.contains(bedrohung)) {
      s = _max(s, h.immun['ailments'] ?? 0);
    }
    return s;
  }

  /// Gegen welche gegnerischen Effekte hilft dieser Held seinem Team wirklich?
  List<String> hilftGegen(Held h) {
    final out = <String>[];
    for (final key in wichtigeBedrohungen) {
      final b = db.bedrohungen[key];
      if (b == null) continue;
      if (b.counters.any(h.effekte.contains)) out.add(key);
    }
    return out;
  }

  /// Gegen welche Effekte federt er nur ab (kein echter Konter)?
  List<String> hilftTeilweise(Held h) {
    final out = <String>[];
    for (final key in wichtigeBedrohungen) {
      final b = db.bedrohungen[key];
      if (b == null) continue;
      if (!b.counters.any(h.effekte.contains) && b.weich.any(h.effekte.contains)) out.add(key);
    }
    return out;
  }

  /// Eigene Stärken des Helden, die vom Gegner ausgehebelt werden können:
  /// eigener Effekt -> gegnerische Effekte, die ihn aushebeln
  Map<String, List<String>> anfaelligFuer(Held h) {
    final out = <String, List<String>>{};
    for (final e in h.effekte) {
      final b = db.bedrohungen[e];
      if (b == null || b.counters.isEmpty) continue;
      out[e] = b.counters;
    }
    return out;
  }

  /// Immunitäten des Helden, sortiert nach Stärke
  List<MapEntry<String, double>> immunitaeten(Held h) {
    final l = h.immun.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return l;
  }

  /// Rollen-Eignung 0..100 (Grundlage für spätere Teamvorschläge)
  Map<String, int> rollenWerte(Held h) {
    final out = <String, int>{};
    final maxAtk = 1500.0, maxDef = 1500.0, maxHp = 2600.0;
    for (final r in db.rollen.values) {
      double eff = 0, effMax = 0;
      r.effekte.forEach((k, w) {
        effMax += w;
        if (h.effekte.contains(k)) eff += w;
      });
      final effAnteil = effMax == 0 ? 0.0 : (eff / effMax).clamp(0.0, 1.0);
      final wert = (r.werte['attack'] ?? 0) * (h.angriff / maxAtk) +
          (r.werte['defense'] ?? 0) * (h.verteidigung / maxDef) +
          (r.werte['health'] ?? 0) * (h.leben / maxHp);
      final gesamt = (effAnteil * 0.65 + wert.clamp(0.0, 1.0) * 0.35) * 100;
      out[r.key] = gesamt.round();
    }
    return out;
  }

  /// Bericht für ein ganzes Team (bis 5 Helden)
  TeamBericht team(List<Held> team) {
    final abgedeckt = <String, List<Held>>{};
    final teilweise = <String, List<Held>>{};
    final luecken = <String>[];
    final immun = <String, List<Held>>{};
    for (final key in wichtigeBedrohungen) {
      final b = db.bedrohungen[key];
      if (b == null) continue;
      final helfer = team.where((h) => b.counters.any(h.effekte.contains)).toList();
      final weich = team.where((h) => b.weich.any(h.effekte.contains)).toList();
      final geschuetzt = team.where((h) => schutz(h, key) >= 0.75).toList();
      if (geschuetzt.isNotEmpty) immun[key] = geschuetzt;
      if (helfer.isNotEmpty) {
        abgedeckt[key] = helfer;
      } else if (weich.isNotEmpty) {
        teilweise[key] = weich;
      } else if (geschuetzt.length < team.length) {
        luecken.add(key);
      }
    }

    // Grundbausteine eines Teams
    bool hat(String e) => team.any((h) => h.effekte.contains(e));
    final bausteine = <String, bool>{
      'Heilung': hat('heal') || hat('heal_ot') || hat('health_boost'),
      'Reinigen': hat('cleanse') || hat('ailment_immune') || hat('ailment_block'),
      'Bannen': hat('dispel') || hat('steal_buff'),
      'Flächenschaden': hat('hit_aoe') || hat('hit_three'),
      'Verteidigung runter': hat('def_down') || hat('elem_def_down') || hat('dmg_taken_up'),
      'Angriff hoch': hat('atk_up'),
      'Mana-Kontrolle': hat('mana_debuff') || hat('mana_cut') || hat('special_block'),
    };

    final farben = <String, int>{};
    final tempo = <String, int>{};
    final familien = <String, int>{};
    int kraft = 0;
    for (final h in team) {
      farben[h.element] = (farben[h.element] ?? 0) + 1;
      tempo[h.tempo] = (tempo[h.tempo] ?? 0) + 1;
      if (h.familie.isNotEmpty) familien[h.familie] = (familien[h.familie] ?? 0) + 1;
      kraft += h.kraft;
    }

    final hinweise = <String>[];
    if (team.isNotEmpty) {
      if (!bausteine['Reinigen']!) {
        hinweise.add('Kein Reinigen im Team – Mana-Verlangsamung und Schaden über Zeit treffen euch voll.');
      }
      if (!bausteine['Bannen']!) {
        hinweise.add('Kein Bannen – gegen Spott, Gegenangriff und Verteidigungsboni wird es schwer.');
      }
      if (!bausteine['Heilung']!) {
        hinweise.add('Keine Heilung – bei langen Kämpfen (Titan, Krieg) fehlt Durchhaltevermögen.');
      }
      if (!bausteine['Verteidigung runter']! && team.length >= 3) {
        hinweise.add('Kein Verteidigung-runter – für Titanen und Angriff ein großer Schadensverlust.');
      }
      final langsam = team.where((h) => h.tempoId == 'slow' || h.tempoId == 'very_slow').length;
      if (langsam >= 3) {
        hinweise.add('$langsam langsame Helden – im Angriff kommen die Fähigkeiten spät.');
      }
      final doppelt = familien.entries.where((e) => e.value >= 2).map((e) => db.familien[e.key]?.name ?? e.key);
      for (final f in doppelt) {
        hinweise.add('Familienbonus aktiv: $f');
      }
    }

    return TeamBericht(
      abgedeckt: abgedeckt,
      teilweise: teilweise,
      luecken: luecken,
      immun: immun,
      bausteine: bausteine,
      farben: farben,
      tempo: tempo,
      kraft: kraft,
      hinweise: hinweise,
    );
  }

  /// Ganze Sammlung: wie viele eigene Helden kontern jede Bedrohung?
  /// Sortiert: zuerst die Bedrohungen mit den wenigsten Kontern.
  List<SammlungsPunkt> sammlungsCheck(List<Held> helden) {
    final out = <SammlungsPunkt>[];
    for (final key in wichtigeBedrohungen) {
      final b = db.bedrohungen[key];
      if (b == null) continue;
      final hart = helden.where((h) => b.counters.any(h.effekte.contains)).toList()
        ..sort((a, x) => x.kraft.compareTo(a.kraft));
      final weich = helden
          .where((h) => !b.counters.any(h.effekte.contains) && b.weich.any(h.effekte.contains))
          .toList()
        ..sort((a, x) => x.kraft.compareTo(a.kraft));
      out.add(SammlungsPunkt(key, hart, weich));
    }
    out.sort((a, b) {
      final c = a.hart.length.compareTo(b.hart.length);
      return c != 0 ? c : a.weich.length.compareTo(b.weich.length);
    });
    return out;
  }

  static double _max(double a, double b) => a > b ? a : b;
}

class SammlungsPunkt {
  final String bedrohung;
  final List<Held> hart;
  final List<Held> weich;
  const SammlungsPunkt(this.bedrohung, this.hart, this.weich);
}

class TeamBericht {
  final Map<String, List<Held>> abgedeckt;
  final Map<String, List<Held>> teilweise;
  final List<String> luecken;
  final Map<String, List<Held>> immun;
  final Map<String, bool> bausteine;
  final Map<String, int> farben;
  final Map<String, int> tempo;
  final int kraft;
  final List<String> hinweise;

  const TeamBericht({
    required this.abgedeckt,
    required this.teilweise,
    required this.luecken,
    required this.immun,
    required this.bausteine,
    required this.farben,
    required this.tempo,
    required this.kraft,
    required this.hinweise,
  });
}
