// E&P Team-Analyzer – Werte für jede Aufstiegsstufe, jedes Level und Limit Break
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Formel aus den Spieldateien (wie HeroPlan): stat = basis * (1000 + ‰) / 1000
//   ‰ = "wahre Level" * proLevel  (+ Limit-Break-Anteile)
//   jede Aufstiegsstufe zählt +3 wahre Level, jeder Limit Break +3 und bis zu +5 Level

import 'dart:math' as math;

class _Param {
  final int proLevel;
  final List<int> stufenMax; // Max-Level je Aufstiegsstufe
  final List<int> lbZusatz; // ‰-Zusatz je Limit Break
  const _Param(this.proLevel, this.stufenMax, this.lbZusatz);
}

const Map<int, _Param> _params = {
  5: _Param(4, [50, 60, 70, 80], [16, 36]),
  4: _Param(5, [40, 50, 60, 70], [18, 41]),
  3: _Param(6, [30, 40, 50], [23, 52]),
  2: _Param(7, [20, 30, 40], []),
  1: _Param(8, [10, 20], []),
};

const Map<int, int> _sternKraft = {1: 0, 2: 10, 3: 30, 4: 50, 5: 90};

int stufenAnzahl(int sterne) => (_params[sterne] ?? _params[5]!).stufenMax.length;
int maxLbAnzahl(int sterne) => (_params[sterne] ?? _params[5]!).lbZusatz.length;

/// Höchstes Level in einer Stufe (in der letzten Stufe inkl. Limit Break)
int maxLevel(int sterne, int stufe, int lb) {
  final p = _params[sterne] ?? _params[5]!;
  final s = stufe.clamp(1, p.stufenMax.length);
  final basis = p.stufenMax[s - 1];
  return s == p.stufenMax.length ? basis + 5 * lb.clamp(0, p.lbZusatz.length) : basis;
}

class Stand {
  final int angriff, verteidigung, leben, kraft;
  const Stand(this.angriff, this.verteidigung, this.leben, this.kraft);
}

/// Werte für Grundwerte [Angriff, Verteidigung, Leben] bei Stufe/Level/LB
Stand berechne(int sterne, List<int> basis, int stufe, int level, int lb) {
  final p = _params[sterne] ?? _params[5]!;
  final s = stufe.clamp(1, p.stufenMax.length);
  final maxLb = p.lbZusatz.length;
  final l = (s == p.stufenMax.length) ? lb.clamp(0, maxLb) : 0;
  final lv = level.clamp(1, maxLevel(sterne, s, l));

  // wahre Level ohne Limit Break
  var wahr = 0;
  for (var i = 0; i < s - 1; i++) {
    wahr += p.stufenMax[i] - 1 + 3;
  }
  final letztesNormal = p.stufenMax[s - 1];
  wahr += math.min(lv, letztesNormal) - 1;
  var promille = 1000 + wahr * p.proLevel;

  // Limit Breaks
  for (var k = 0; k < l; k++) {
    final startLevel = letztesNormal + 5 * k;
    final level = (lv - startLevel).clamp(0, 5);
    promille += (3 + level) * (p.proLevel + p.lbZusatz[k]);
  }

  int st(int b) => (b * promille / 1000).truncate();
  final a = st(basis[0]), d = st(basis[1]), h = st(basis[2]);
  final kraft = (_sternKraft[sterne] ?? 0) + (a * 0.35 + d * 0.28 + h * 0.14).floor() + 35;
  return Stand(a, d, h, kraft);
}

/// Aus einem im Spiel abgelesenen Level die wahrscheinlichste Stufe ableiten.
/// Über dem Max-Level der letzten Stufe -> Limit Break (85 = LB1, 90 = LB2 bei 5★).
/// Sonst: kleinste Stufe, deren Max-Level das Level noch fasst.
({int stufe, int level, int lb}) standAusLevel(int sterne, int level) {
  final p = _params[sterne] ?? _params[5]!;
  final letzte = p.stufenMax.length;
  final cap = p.stufenMax.last;
  if (level > cap && p.lbZusatz.isNotEmpty) {
    final lb = ((level - cap + 4) ~/ 5).clamp(1, p.lbZusatz.length);
    return (stufe: letzte, level: level.clamp(1, cap + 5 * lb), lb: lb);
  }
  for (var s = 1; s <= letzte; s++) {
    if (level <= p.stufenMax[s - 1]) {
      return (stufe: s, level: level.clamp(1, p.stufenMax[s - 1]), lb: 0);
    }
  }
  return (stufe: letzte, level: cap, lb: 0);
}
