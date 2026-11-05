// E&P Team-Analyzer – Helden-Datenbank
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sprache.dart';

class Effekt {
  final String key;
  final String labelDe;
  final String gruppe;
  final String labelEn;
  const Effekt(this.key, this.labelDe, this.gruppe, [this.labelEn = '']);
  String get label => Sprache.en && labelEn.isNotEmpty ? labelEn : labelDe;
}

class Bedrohung {
  final String key;
  final String labelDe;

  /// Effekte, die die Bedrohung wirklich aushebeln
  final List<String> counters;

  /// Effekte, die sie nur abfedern
  final List<String> weich;
  final String tippDe;
  final String labelEn;
  final String tippEn;
  const Bedrohung(this.key, this.labelDe, this.counters, this.tippDe,
      [this.weich = const [], this.labelEn = '', this.tippEn = '']);
  String get label => Sprache.en && labelEn.isNotEmpty ? labelEn : labelDe;
  String get tipp => Sprache.en && tippEn.isNotEmpty ? tippEn : tippDe;
}

class Passiv {
  final String id;
  final String titelDe;
  final String textDe;
  final String titelEn;
  final String textEn;
  const Passiv(this.id, this.titelDe, this.textDe, [this.titelEn = '', this.textEn = '']);
  String get titel => Sprache.en && titelEn.isNotEmpty ? titelEn : titelDe;
  String get text => Sprache.en && textEn.isNotEmpty ? textEn : textDe;
}

class Familie {
  final String id;
  final String nameDe;
  final List<String> bonusDe;
  final String nameEn;
  final List<String> bonusEn;
  const Familie(this.id, this.nameDe, this.bonusDe, [this.nameEn = '', this.bonusEn = const []]);
  String get name => Sprache.en && nameEn.isNotEmpty ? nameEn : nameDe;
  List<String> get bonus => Sprache.en && bonusEn.isNotEmpty ? bonusEn : bonusDe;
}

class Rolle {
  final String key;
  final String labelDe;
  final Map<String, double> effekte;
  final Map<String, double> werte;
  final String labelEn;
  const Rolle(this.key, this.labelDe, this.effekte, this.werte, [this.labelEn = '']);
  String get label => Sprache.en && labelEn.isNotEmpty ? labelEn : labelDe;
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

  // Englisch
  final String titelEn;
  final String klasseEn;
  final String klasseKey; // wizard, ranger, … (für Truppen)
  final String tempoEn;
  final String spezialNameEn;
  final List<String> spezialEn;
  final String aetherEn;

  /// Nur beim Basis-Helden: Kostümbonus je erreichter Kostüm-Stufe [Angriff‰, Verteidigung‰, Leben‰, Mana‰]
  final List<List<int>> kostuemTabelle;

  /// Aufstiegsstufen pro Kostüm (4 bei 4–5★, sonst 3)
  final int kostuemStufen;
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
    this.titelEn = '',
    this.klasseEn = '',
    this.klasseKey = '',
    this.tempoEn = '',
    this.spezialNameEn = '',
    this.spezialEn = const [],
    this.aetherEn = '',
    this.kostuemTabelle = const [],
    this.kostuemStufen = 4,
  }) : _such = '$name $nameEn $titel $titelEn $spezialName $spezialNameEn'.toLowerCase();

  /// Kopie mit zusätzlichen Effekten/Immunitäten (z. B. durch die Truppe)
  Held mitZusatz({Set<String> effekte = const {}, Map<String, double> immun = const {}}) {
    final im = {...this.immun};
    immun.forEach((k, v) => im[k] = (im[k] ?? 0) > v ? im[k]! : v);
    return Held(
      id: id,
      name: name,
      nameEn: nameEn,
      titel: titel,
      sterne: sterne,
      element: element,
      klasse: klasse,
      familie: familie,
      tempoId: tempoId,
      tempo: tempo,
      datum: datum,
      quelle: quelle,
      werte: werte,
      basis: basis,
      spezialName: spezialName,
      spezial: spezial,
      passive: passive,
      effekte: {...this.effekte, ...effekte},
      immun: im,
      kostuemVon: kostuemVon,
      kostuemTyp: kostuemTyp,
      kommend: kommend,
      unvollstaendig: unvollstaendig,
      aether: aether,
      titelEn: titelEn,
      klasseEn: klasseEn,
      klasseKey: klasseKey,
      tempoEn: tempoEn,
      spezialNameEn: spezialNameEn,
      spezialEn: spezialEn,
      aetherEn: aetherEn,
      kostuemTabelle: kostuemTabelle,
      kostuemStufen: kostuemStufen,
    );
  }

  // Anzeige in der eingestellten Sprache
  String get nameL => Sprache.en && nameEn.isNotEmpty ? nameEn : name;
  String get titelL => Sprache.en && titelEn.isNotEmpty ? titelEn : titel;
  String get klasseL => Sprache.en && klasseEn.isNotEmpty ? klasseEn : klasse;
  String get tempoL => Sprache.en && tempoEn.isNotEmpty ? tempoEn : tempo;
  String get spezialNameL => Sprache.en && spezialNameEn.isNotEmpty ? spezialNameEn : spezialName;
  List<String> get spezialL => Sprache.en && spezialEn.isNotEmpty ? spezialEn : spezial;
  String get aetherL => Sprache.en && aetherEn.isNotEmpty ? aetherEn : aether;
  String get kostuemL {
    final k = kostuemTyp;
    if (k == null || !Sprache.en) return k ?? '';
    return const {'Glas': 'Glass', 'Stilvoll': 'Stylish', 'Kostüm': 'Costume'}[k] ?? k;
  }

  String get anzeigeName => kostuemTyp == null ? nameL : '$nameL ($kostuemL)';
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
      titelEn: (j['tie'] ?? '') as String,
      klasseEn: (j['ke'] ?? '') as String,
      klasseKey: (j['kk'] ?? '') as String,
      tempoEn: (j['spe'] ?? '') as String,
      spezialNameEn: (j['skne'] ?? '') as String,
      spezialEn: List<String>.from(j['ske'] as List? ?? const []),
      aetherEn: (j['aee'] ?? '') as String,
      kostuemTabelle: [
        for (final e in (j['cb'] as List? ?? const [])) [for (final v in e as List) (v as num).toInt()],
      ],
      kostuemStufen: (j['cs'] as num?)?.toInt() ?? 4,
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
  final Map<String, dynamic> truppenRoh;

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
    this.truppenRoh = const {},
  }) : nachId = {for (final h in helden) h.id: h};

  static Future<Datenbank> laden() async {
    final text = await rootBundle.loadString('assets/data/helden.json');
    return compute(_parsen, text);
  }

  String effektName(String key) => effekte[key]?.label ?? key;
  String bedrohungName(String key) => bedrohungen[key]?.label ?? effektName(key);
  String bedrohungTipp(String key) => bedrohungen[key]?.tipp ?? '';

  /// Nur die Kostüme eines Helden (ohne Basis)
  List<Held> kostuemeVon(Held h) => varianten(h).where((v) => v.kostuemVon != null).toList();

  /// Kostümbonus-Tabelle der Heldengruppe (steht am Basis-Helden)
  List<List<int>> kostuemTabelle(Held h) => nachId[h.basisId]?.kostuemTabelle ?? const [];
  int kostuemStufen(Held h) => nachId[h.basisId]?.kostuemStufen ?? 4;

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
    effekte[k] = Effekt(k, m['l'] as String, m['g'] as String, (m['le'] ?? '') as String);
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
      (m['le'] ?? '') as String,
      (m['te'] ?? '') as String,
    );
  });

  final rollen = <String, Rolle>{};
  (j['rollen'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    Map<String, double> zahlen(dynamic x) =>
        (x as Map<String, dynamic>).map((a, b) => MapEntry(a, (b as num).toDouble()));
    rollen[k] = Rolle(k, m['label'] as String, zahlen(m['effekte']), zahlen(m['werte']), (m['le'] ?? '') as String);
  });

  final passive = <String, Passiv>{};
  (j['passive'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    passive[k] = Passiv(k, (m['t'] ?? '') as String, (m['x'] ?? '') as String, (m['te'] ?? '') as String,
        (m['xe'] ?? '') as String);
  });

  final familien = <String, Familie>{};
  (j['familien'] as Map<String, dynamic>).forEach((k, v) {
    final m = v as Map<String, dynamic>;
    familien[k] = Familie(k, (m['n'] ?? k) as String, List<String>.from(m['b'] as List? ?? const []),
        (m['ne'] ?? '') as String, List<String>.from(m['be'] as List? ?? const []));
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
    truppenRoh: (j['truppen'] as Map<String, dynamic>?) ?? const {},
  );
}
