// E&P Team-Analyzer – wie weit ein Gegner-Held ausgebaut ist (Stufe, Level, LB, Talent, Kostüme)
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'datenbank.dart';
import 'sprache.dart';
import 'werte.dart';

class GegnerStand {
  int stufe, level, lb, talent;

  /// Kostüm-ID -> Stufe (0 = hat er nicht)
  Map<String, int> kost;

  /// Stärke laut Spiel (Screenshot oder von Hand) – hat Vorrang vor der Berechnung
  int? staerke;

  GegnerStand({required this.stufe, required this.level, this.lb = 0, this.talent = 0, Map<String, int>? kost, this.staerke})
      : kost = kost ?? {};

  /// Standard: voll aufgestiegen, kein Limit Break, keine Kostüme
  factory GegnerStand.standard(Held h) {
    final s = stufenAnzahl(h.sterne);
    return GegnerStand(stufe: s, level: maxLevel(h.sterne, s, 0));
  }

  GegnerStand kopie() =>
      GegnerStand(stufe: stufe, level: level, lb: lb, talent: talent, kost: Map.of(kost), staerke: staerke);

  int get kostuemStufen => kost.values.fold(0, (a, b) => a + b);
  int get kostuemAnzahl => kost.values.where((v) => v > 0).length;

  Stand werte(Datenbank db, Held h) => berechne(h.sterne, h.basis, stufe, level, lb,
      talent: talent, kostuemBonus: kostuemBonusFuer(db.kostuemTabelle(h), kostuemStufen));

  int kraft(Datenbank db, Held h) => staerke ?? werte(db, h).kraft;

  /// Kurzinfo unter dem Porträt, z. B. "LB1 · 2 Kost. · +20"
  String kurz(Held h) => [
        if (stufe < stufenAnzahl(h.sterne)) '${tx('St.', 'Asc.')} $stufe',
        if (lb > 0) 'LB$lb',
        if (kostuemAnzahl > 0) '$kostuemAnzahl ${tx('Kost.', 'cost.')}',
        if (talent > 0) '+$talent',
      ].join(' · ');
}
