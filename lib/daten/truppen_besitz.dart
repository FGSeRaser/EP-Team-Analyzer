// E&P Team-Analyzer – eigene Truppen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'sprache.dart';
import 'truppen.dart';

/// Eine Truppe aus der Kaserne des Spielers
class EigeneTruppe {
  final String id; // eindeutig (Zeitstempel)
  String farbe; // rot, blau, gruen, gelb, lila
  String typ; // mana, krit, magie, styx, ninja, leg, normal
  String? legName; // bei legendären Truppen
  int sterne; // bei normalen Truppen 1–3, sonst 4/5
  int level;
  int anzahl;

  EigeneTruppe({
    required this.id,
    required this.farbe,
    required this.typ,
    this.legName,
    this.sterne = 4,
    this.level = 1,
    this.anzahl = 1,
  });

  static int maxLevel(String typ, int sterne) => switch (typ) {
        'leg' => 40,
        'normal' => sterne <= 1 ? 10 : (sterne == 2 ? 15 : 22),
        _ => 30,
      };

  String typName(TruppenWissen w) => switch (typ) {
        'leg' => legName ?? tx('Legendär', 'Legendary'),
        'normal' => tx('$sterne★-Truppe', '$sterne★ troop'),
        _ => w.epischNach(typ)?.label ?? typ,
      };

  /// Kurz für Anzeigen: "Magie 25"
  String kurz(TruppenWissen w) {
    final name = switch (typ) {
      'leg' => legName ?? 'Leg.',
      'normal' => '$sterne★',
      'mana' => 'Mana',
      'krit' => tx('Krit', 'Crit'),
      'magie' => tx('Magie', 'Magic'),
      'styx' => 'Styx',
      'ninja' => 'Ninja',
      _ => typ,
    };
    return '$name $level';
  }

  /// Mana-Bonus in % bei diesem Level (aus den Stufen-Tabellen)
  int manaProzent(TruppenWissen w) => _stufe(w.epischNach(typ)?.mana ?? const [], level);
  int kritProzent(TruppenWissen w) => _stufe(w.epischNach(typ)?.krit ?? const [], level);
  int umgehenProzent(TruppenWissen w) => _stufe(w.epischNach(typ)?.umgehen ?? const [], level);

  static int _stufe(List<List<int>> tabelle, int level) {
    var wert = 0;
    for (final e in tabelle) {
      if (level >= e[0]) wert = e[1];
    }
    return wert;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'f': farbe,
        't': typ,
        if (legName != null) 'n': legName,
        's': sterne,
        'l': level,
        if (anzahl != 1) 'a': anzahl,
      };

  factory EigeneTruppe.ausJson(Map<String, dynamic> j) => EigeneTruppe(
        id: j['id'] as String,
        farbe: j['f'] as String,
        typ: j['t'] as String,
        legName: j['n'] as String?,
        sterne: (j['s'] as num?)?.toInt() ?? 4,
        level: (j['l'] as num?)?.toInt() ?? 1,
        anzahl: (j['a'] as num?)?.toInt() ?? 1,
      );
}
