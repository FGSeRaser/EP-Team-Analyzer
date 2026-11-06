// E&P Team-Analyzer – News: offizielle Meldungen, Held des Monats, neue Helden
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Die offiziellen News sammelt ein GitHub-Workflow alle 6 Stunden in news/news.json
// (Quelle: empiresandpuzzles.com/news). Die App lädt diese Datei und merkt sich die
// letzte Fassung für unterwegs ohne Netz.

import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'datenbank.dart';
import 'sprache.dart';
import 'updater.dart' show githubRepo;

class NewsArtikel {
  final String titel, url, kurz, text;
  final DateTime datum;
  final List<String> arten;
  const NewsArtikel(this.titel, this.datum, this.url, this.arten, this.kurz, this.text);

  factory NewsArtikel.ausJson(Map<String, dynamic> j) => NewsArtikel(
        (j['titel'] ?? '') as String,
        DateTime.tryParse((j['datum'] ?? '') as String) ?? DateTime(2000),
        (j['url'] ?? '') as String,
        [for (final a in (j['arten'] as List? ?? const [])) a as String],
        (j['kurz'] ?? '') as String,
        (j['text'] ?? '') as String,
      );

  bool get balance => arten.contains('balance');
}

String newsArtName(String a) => switch (a) {
      'balance' => tx('Balance', 'Balance'),
      'version' => tx('Update', 'Update'),
      'kalender' => tx('Kalender', 'Calendar'),
      'statistik' => tx('Statistik', 'Stats'),
      'event' => 'Event',
      _ => 'Info',
    };

class NewsStand {
  final List<NewsArtikel> artikel;
  final String stand;
  final bool ausCache;
  final String? fehler;
  const NewsStand(this.artikel, this.stand, {this.ausCache = false, this.fehler});
}

class NewsDienst {
  static const quelle = 'https://raw.githubusercontent.com/$githubRepo/main/news/news.json';
  static const _cacheKey = 'news_cache';
  static const _gesehenKey = 'news_gesehen';

  static NewsStand _parsen(String text, {bool ausCache = false, String? fehler}) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final l = [for (final a in (j['artikel'] as List? ?? const [])) NewsArtikel.ausJson(a as Map<String, dynamic>)]
      ..sort((a, b) => b.datum.compareTo(a.datum));
    return NewsStand(l, (j['stand'] ?? '') as String, ausCache: ausCache, fehler: fehler);
  }

  static Future<NewsStand> laden() async {
    final prefs = await SharedPreferences.getInstance();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      // Zeitstempel gegen Zwischenspeicher von GitHub
      final req = await client.getUrl(Uri.parse('$quelle?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'));
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final text = await res.transform(utf8.decoder).join();
      final stand = _parsen(text);
      await prefs.setString(_cacheKey, text);
      return stand;
    } catch (e) {
      final alt = prefs.getString(_cacheKey);
      if (alt != null) return _parsen(alt, ausCache: true, fehler: '$e');
      return NewsStand(const [], '', fehler: '$e');
    } finally {
      client.close(force: true);
    }
  }

  /// Datum des neuesten bereits gesehenen Artikels
  static Future<DateTime?> gesehenBis() async {
    final p = await SharedPreferences.getInstance();
    return DateTime.tryParse(p.getString(_gesehenKey) ?? '');
  }

  static Future<void> alsGesehen(DateTime d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_gesehenKey, d.toIso8601String());
  }
}

// ---------------------------------------------------------------------------
// Held des Monats & neue Helden (aus der Heldendatenbank)
// ---------------------------------------------------------------------------

const _monateEn = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const _monateDe = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
];

String monatName(int jahr, int monat) => tx('${_monateDe[monat - 1]} $jahr', '${_monateEn[monat - 1]} $jahr');

/// Alle Helden aus dem Held-des-Monats-Paket (5★ zuerst, dann die 4★-Begleiter)
List<Held> heldenDesMonats(Datenbank db, int jahr, int monat) {
  final q = 'MonthlyHero${_monateEn[monat - 1]}$jahr';
  final l = db.helden.where((h) => h.quelle == q && h.kostuemVon == null).toList()
    ..sort((a, b) => b.sterne.compareTo(a.sterne));
  return l;
}

/// Neue und angekündigte Helden (Erscheinungsdatum in den letzten [tage] Tagen oder später)
List<Held> neueHelden(Datenbank db, {int tage = 45, DateTime? heute}) {
  final ab = (heute ?? DateTime.now()).subtract(Duration(days: tage));
  final l = db.helden.where((h) {
    if (h.kostuemVon != null) return false;
    final d = DateTime.tryParse(h.datum);
    return (d != null && d.isAfter(ab)) || h.kommend;
  }).toList()
    ..sort((a, b) => b.datum.compareTo(a.datum));
  return l;
}

/// Helden, deren (englischer) Name im Artikeltext vorkommt
List<Held> erwaehnteHelden(Datenbank db, String text) {
  if (text.isEmpty) return const [];
  final gefunden = <String, Held>{};
  for (final h in db.helden) {
    if (h.kostuemVon != null || h.sterne < 3) continue;
    final n = h.nameEn.isNotEmpty ? h.nameEn : h.name;
    if (n.length < 4 || gefunden.containsKey(n)) continue;
    if (RegExp('\\b${RegExp.escape(n)}\\b').hasMatch(text)) gefunden[n] = h;
  }
  final l = gefunden.values.toList()..sort((a, b) => b.sterne.compareTo(a.sterne));
  return l.take(40).toList();
}
