// E&P Team-Analyzer – Sprache Deutsch / Englisch
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Sprache extends ChangeNotifier {
  Sprache._();
  static final Sprache instanz = Sprache._();
  static const _schluessel = 'sprache';

  bool _en = false;

  /// true = Englisch
  static bool get en => instanz._en;

  Future<void> laden() async {
    final prefs = await SharedPreferences.getInstance();
    _en = prefs.getString(_schluessel) == 'en';
    notifyListeners();
  }

  Future<void> setzen(bool englisch) async {
    if (englisch == _en) return;
    _en = englisch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_schluessel, englisch ? 'en' : 'de');
    notifyListeners();
  }
}

/// Text in der aktuellen Sprache: tx('Deutsch', 'English')
String tx(String de, String en) => Sprache.en ? en : de;
