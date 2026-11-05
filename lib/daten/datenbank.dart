// E&P Team-Analyzer – Helden-Datenbank
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Effekt {
  final String key;
  final String label;
  final String gruppe;
  const Effekt(this.key, this.label, this.gruppe);
}

class Bedrohung {
  final String key;
  final String label;

  /// Effekte, die die Bedrohung wirklich aushebeln
  final List<String> counters;

  /// Effekte, die sie nur abfedern
  final List<String> weich;
  final String tipp;
  const Bedrohung(this.key, this.label, this.counters, this.tipp, [this.weich = const []]);
}

class Passiv {
  final String id;
  final String titel;
  final String text;
  const Passiv(this.id, this.titel, this.text);
}

class Familie {
  final String id;
  final String name;
  final List<String> bonus;
  const Familie(this.id, this.name, this.bonus);
}

class Rolle {
  final String key;
  final String label;
  final Map<String, double> effekte;
  final Map<String, double> werte;
  const Rolle(this.key, this.label, this.effekte, this.werte);
}

class Held {
  final String id;
  final String name;
  final String nameEn;
  final String titel;
  final int sterne;
  final String element; // rot, blau, gruen, gelb, lila
  final String klasse;
  final String familie;
  final String tempoId;
  final String tempo;
  final String datum;
  final String quelle;

  /// [Max, LB1, LB2] -> jeweils [Angriff, Verteidigung, Leben, Kraft]
  final List<List<int>> werte;

  /// Grundwerte [Angriff, Verteidigung, Leben] auf Stufe 1, Level 1
  final List<int> basis;
  final String spezialName;
  final List<String> spezial;
  final List<String> passive;
  final Set<String> effekte;

  /// Bedrohung -> Schutzstärke (1.0 = immun, 0.75 = 75% Chance …)
  final Map<String, double> immun;
  final String? kostuemVon;
  final String? kostuemTyp;
  final bool kommend;

  /// Fähigkeit im Spiel noch ein Platzhalter (Held ohne Termin)
  final bool unvollstaendig;
  final String aether;
  final String _such;

  Held({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.titel,
    required this.sterne,
    required this.element,
    required this.klasse,
    required this.familie,
    required this.tempoId,
    required this.tempo,
    required this.datum,
    required this.quelle,
    required this.werte,
    required this.basis,
    required this.spezialName,
    required this.spezial,
    required this.passive,
    required this.effekte,
    required this.immun,
    required this.kostuemVon,
    required this.kostuemTyp,
    required this.kommend,
    this.unvollstaendig = false,
    required this.aether,
  }) : _such = '$name $nameEn $titel $spezialName'.toLowerCase();

  String get anzeigeName => kostuemTyp == null ? name : '$name ($kostuemTyp)';
  List<int> get maxWerte => werte[2];
  int get kraft => werte[2][3];
  int get angriff => werte[2][0];
  int get verteidigung => werte[2][1];
  int get leben => werte[2][2];
  String get basisId => kostuemVon ?? id;
  String get bildUrl => 'https://heroplan.github.io/imgs/hero_icon/$id.webp';
  bool passtZuSuche(String q) => q.isEmpty || _such.contains(q);

  factory Held.ausJson(Map<String, dynamic> j) {
    final w = (j['w'] as List)
        .map((x) => (x as List).map((v) => (v as num).toInt()).toList())
        .toList();
    final im = <String, double>{};
    final imJ = j['im'];
    if (imJ is Map) {
      imJ.forEach((k, v) => im[k as String] = (v as num).toDouble());
    }
    return Held(
      id: j['id'] as String,
      name: j['n'] as String,
      nameEn: (j['en'] ?? '') as String,
      titel: (j['ti'] ?? '') as String,
      sterne: (j['s'] as num).toInt(),
      element: j['e'] as String,
      klasse: (j['k'] ?? '') as String,
      familie: (j['fa'] ?? '') as String,
      tempoId: (j['sp'] ?? '') as String,
      tempo: (j['spn'] ?? '') as String,
      datum: (j['d'] ?? '') as String,
      quelle: (j['q'] ?? '') as String,
      werte: w,
      basis: (j['b'] as List? ?? const [0, 0, 0]).map((v) => (v as num).toInt()).toList(),
      spezialName: (j['skn'] ?? '') as String,
      spezial: List<String>.from(j['sk'] as List? ?? const []),
      passive: List<String>.from(j['p'] as List? ?? const []),
      effekte: Set<String>.from(j['fx'] as List? ?? const []),
      immun: im,
      kostuemVon: j['c'] as String?,
      kostuemTyp: j['ct'] as String?,
      kommend: j['neu'] == 1,
      unvollstaendig: j['uv'] == 1,
      aether: (j['ae'] ?? '') as String,
    );
  }
}

class Datenbank {
  final String version;
  final String quelle;
  final Map<String, Effekt> effekte;
  final Map<String, Bedrohung> bedrohungen;
  final Set<String> leidenBedrohungen;
  final Map<String, Rolle> rollen;
  final Map<String, Passiv> passive;
  final Map<String, Familie> familien;
  final List<Held> helden;
  final Map<String, Held> nachId;

  Datenbank({
    required this.version,
    required this.quelle,
    required this.effekte,
    required this.bedrohungen,
    required this.leidenBedrohungen,
    required this.rollen,
    required this.passive,
    required this.familien,
    required this.helden,
  }) : nachId = {for (final h in helden) h.id: h};

  static Future<Datenbank> laden() async {
    final text = await rootBundle.loadString('assets/data/helden.json');
    return compute(_parsen, text);
  }

  String effektName(String key) => effekte[key]?.label ?? key;
  String bedrohungName(String key) => bedrohungen[key]?.label ?? effektName(key);

  /// Alle Varianten eines Helden (Basis + Kostüme)
  List<Held> varianten(Held h) {
    final basis = h.basisId;
    return helden.where((x) => x.basisId == basis).toList()
      ..sort((a, b) => (a.kostuemTyp ?? '').compareTo(b.kostuemTyp ?? ''));
  }
}

Datenbank _parsen(String text) {
  final j = jsonDecode(text) as Map<String, dynamic>;

  final effekte = <String, Effekt>{};
  (j['effekte'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    effekte[k] = Effekt(k, m['l'] as String, m['g'] as String);
  });

  final bedrohungen = <String, Bedrohung>{};
  (j['bedrohungen'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    bedrohungen[k] = Bedrohung(
      k,
      m['label'] as String,
      List<String>.from(m['counters'] as List),
      (m['tipp'] ?? '') as String,
      List<String>.from(m['weich'] as List? ?? const []),
    );
  });

  final rollen = <String, Rolle>{};
  (j['rollen'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    Map<String, double> zahlen(dynamic x) =>
        (x as Map<String, dynamic>).map((a, b) => MapEntry(a, (b as num).toDouble()));
    rollen[k] = Rolle(k, m['label'] as String, zahlen(m['effekte']), zahlen(m['werte']));
  });

  final passive = <String, Passiv>{};
  (j['passive'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    passive[k] = Passiv(k, (m['t'] ?? '') as String, (m['x'] ?? '') as String);
  });

  final familien = <String, Familie>{};
  (j['familien'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    familien[k] = Familie(k, (m['n'] ?? k) as String, List<String>.from(m['b'] as List? ?? const []));
  });

  final helden = (j['helden'] as List)
      .map((x) => Held.ausJson(x as Map<String, dynamic>))
      .toList();

  return Datenbank(
    version: (j['version'] ?? '') as String,
    quelle: (j['quelle'] ?? '') as String,
    effekte: effekte,
    bedrohungen: bedrohungen,
    leidenBedrohungen: Set<String>.from(j['leidenBedrohungen'] as List),
    rollen: rollen,
    passive: passive,
    familien: familien,
    helden: helden,
  );
}
