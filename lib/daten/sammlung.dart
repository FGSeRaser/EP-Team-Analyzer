// E&P Team-Analyzer – eigene Heldensammlung (wird auf dem Handy gespeichert)
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'datenbank.dart';
import 'werte.dart';

/// Ein Held, den der Spieler besitzt
class Besitz {
  final String id;
  int anzahl;
  int stufe; // Aufstiegsstufe 1..4 (5★)
  int level;
  int lb; // Limit Break 0..2
  int talent; // Talentpunkte 0..25
  int? staerke; // Stärke laut Spiel (inkl. Embleme/Kostüm), aus Screenshot oder von Hand
  String notiz;

  Besitz({
    required this.id,
    this.anzahl = 1,
    this.stufe = 1,
    this.level = 1,
    this.lb = 0,
    this.talent = 0,
    this.staerke,
    this.notiz = '',
  });

  /// Neu hinzugefügte Helden gelten erstmal als "maximal ohne Limit Break"
  factory Besitz.max(Held h) => Besitz(
        id: h.id,
        stufe: stufenAnzahl(h.sterne),
        level: maxLevel(h.sterne, stufenAnzahl(h.sterne), 0),
      );

  bool istMax(Held h) => stufe >= stufenAnzahl(h.sterne) && level >= maxLevel(h.sterne, stufe, lb);

  Stand werte(Held h) => berechne(h.sterne, h.basis, stufe, level, lb);

  String standText(Held h) {
    final teile = <String>[];
    if (istMax(h) && lb == 0) {
      teile.add('Max');
    } else {
      teile.add('$stufe/${stufenAnzahl(h.sterne)} · Lv $level');
    }
    if (lb > 0) teile.add('LB$lb');
    if (talent > 0) teile.add('+$talent');
    return teile.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (anzahl != 1) 'n': anzahl,
        's': stufe,
        'l': level,
        if (lb != 0) 'lb': lb,
        if (talent != 0) 't': talent,
        if (staerke != null) 'st': staerke,
        if (notiz.isNotEmpty) 'x': notiz,
      };

  factory Besitz.ausJson(Map<String, dynamic> j) => Besitz(
        id: j['id'] as String,
        anzahl: (j['n'] as num?)?.toInt() ?? 1,
        stufe: (j['s'] as num?)?.toInt() ?? 1,
        level: (j['l'] as num?)?.toInt() ?? 1,
        lb: (j['lb'] as num?)?.toInt() ?? 0,
        talent: (j['t'] as num?)?.toInt() ?? 0,
        staerke: (j['st'] as num?)?.toInt(),
        notiz: (j['x'] as String?) ?? '',
      );
}

/// Ein Held, der neu dazukommt – optional mit abgelesenem Stand
class NeuerHeld {
  final Held held;
  final int? level;
  final int? talent;
  final int? staerke;
  const NeuerHeld(this.held, {this.level, this.talent, this.staerke});

  Besitz alsBesitz() {
    final b = Besitz.max(held);
    if (level != null) {
      final st = standAusLevel(held.sterne, level!);
      b
        ..stufe = st.stufe
        ..level = st.level
        ..lb = st.lb;
    }
    if (talent != null && held.sterne >= 3) b.talent = talent!.clamp(0, 25);
    b.staerke = staerke;
    return b;
  }
}

class Sammlung extends ChangeNotifier {
  static const _schluessel = 'sammlung_v1';
  final Map<String, Besitz> _helden = {};

  Iterable<Besitz> get alle => _helden.values;
  int get anzahlVerschiedene => _helden.length;
  int get anzahlGesamt => _helden.values.fold(0, (a, b) => a + b.anzahl);
  Set<String> get ids => _helden.keys.toSet();
  bool hat(String id) => _helden.containsKey(id);
  Besitz? besitz(String id) => _helden[id];

  Future<void> laden() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_schluessel);
    _helden.clear();
    if (text != null && text.isNotEmpty) {
      try {
        _importiere(text, ersetzen: true);
      } catch (_) {
        // kaputte Daten ignorieren
      }
    }
    notifyListeners();
  }

  Future<void> _speichern() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schluessel, exportieren());
  }

  Future<int> hinzufuegen(Iterable<Held> helden, {bool nurNeue = true}) =>
      hinzufuegenMitStand([for (final h in helden) NeuerHeld(h)], nurNeue: nurNeue);

  /// Fügt Helden hinzu (doppelte in der Liste = mehrere Exemplare).
  /// Level/Talent/Stärke aus dem Screenshot werden übernommen; bei mehreren
  /// Exemplaren zählt das stärkste. Mit [nurNeue] werden Helden, die schon
  /// VORHER in der Sammlung waren, nicht verändert.
  Future<int> hinzufuegenMitStand(List<NeuerHeld> liste, {bool nurNeue = true}) async {
    final vorher = ids;
    var neu = 0;
    for (final n in liste) {
      final h = n.held;
      if (nurNeue && vorher.contains(h.id)) continue;
      final b = _helden[h.id];
      final kandidat = n.alsBesitz();
      if (b == null) {
        _helden[h.id] = kandidat;
      } else {
        if (!vorher.contains(h.id) || !nurNeue) b.anzahl++;
        // Stärkeres Exemplar bestimmt den angezeigten Stand
        if ((kandidat.staerke ?? 0) > (b.staerke ?? 0)) {
          b
            ..stufe = kandidat.stufe
            ..level = kandidat.level
            ..lb = kandidat.lb
            ..talent = kandidat.talent
            ..staerke = kandidat.staerke;
        }
      }
      neu++;
    }
    await _speichern();
    notifyListeners();
    return neu;
  }

  Future<void> aktualisieren(Besitz b) async {
    if (b.anzahl <= 0) {
      _helden.remove(b.id);
    } else {
      _helden[b.id] = b;
    }
    await _speichern();
    notifyListeners();
  }

  Future<void> entfernen(String id) async {
    _helden.remove(id);
    await _speichern();
    notifyListeners();
  }

  Future<void> leeren() async {
    _helden.clear();
    await _speichern();
    notifyListeners();
  }

  String exportieren() => jsonEncode({
        'app': 'E&P Team-Analyzer (FGSeRaser)',
        'version': 1,
        'helden': [for (final b in _helden.values) b.toJson()],
      });

  /// Liefert die Anzahl importierter Helden
  Future<int> importieren(String text, {bool ersetzen = false}) async {
    final n = _importiere(text, ersetzen: ersetzen);
    await _speichern();
    notifyListeners();
    return n;
  }

  int _importiere(String text, {required bool ersetzen}) {
    final j = jsonDecode(text);
    final liste = j is Map ? (j['helden'] as List? ?? const []) : (j as List);
    if (ersetzen) _helden.clear();
    var n = 0;
    for (final x in liste) {
      final b = Besitz.ausJson(Map<String, dynamic>.from(x as Map));
      _helden[b.id] = b;
      n++;
    }
    return n;
  }

  /// Nur Besitz-Einträge, deren Held in der Datenbank existiert
  List<MapEntry<Held, Besitz>> mitHelden(Datenbank db) {
    final out = <MapEntry<Held, Besitz>>[];
    for (final b in _helden.values) {
      final h = db.nachId[b.id];
      if (h != null) out.add(MapEntry(h, b));
    }
    return out;
  }
}
