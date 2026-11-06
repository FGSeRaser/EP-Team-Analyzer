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
  final String titelDe, textDe;
  final DateTime datum;
  final List<String> arten;
  const NewsArtikel(this.titel, this.datum, this.url, this.arten, this.kurz, this.text,
      {this.titelDe = '', this.textDe = ''});

  factory NewsArtikel.ausJson(Map<String, dynamic> j) => NewsArtikel(
        (j['titel'] ?? '') as String,
        DateTime.tryParse((j['datum'] ?? '') as String) ?? DateTime(2000),
        (j['url'] ?? '') as String,
        [for (final a in (j['arten'] as List? ?? const [])) a as String],
        (j['kurz'] ?? '') as String,
        (j['text'] ?? '') as String,
        titelDe: (j['titel_de'] ?? '') as String,
        textDe: (j['text_de'] ?? '') as String,
      );

  /// In der eingestellten Sprache (Deutsch = maschinell übersetzt, sonst Original)
  String get titelL => !Sprache.en && titelDe.isNotEmpty ? titelDe : titel;
  String get textL => !Sprache.en && textDe.isNotEmpty ? textDe : text;
  bool get hatDeutsch => textDe.isNotEmpty || titelDe.isNotEmpty;

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

/// Ein Termin aus dem offiziellen Event-Kalender (Zeiten in UTC)
class EventTermin {
  final String name, nameDe, symbol, artikel;
  final DateTime start, ende;
  const EventTermin(this.name, this.symbol, this.start, this.ende, this.artikel, {this.nameDe = ''});

  factory EventTermin.ausJson(Map<String, dynamic> j) => EventTermin(
        (j['name'] ?? '') as String,
        (j['symbol'] ?? '') as String,
        DateTime.parse((j['start'] as String).replaceAll('Z', ':00Z')),
        DateTime.parse((j['ende'] as String).replaceAll('Z', ':00Z')),
        (j['artikel'] ?? '') as String,
        nameDe: (j['name_de'] ?? '') as String,
      );

  String get nameL => !Sprache.en && nameDe.isNotEmpty ? nameDe : name;

  bool laeuft(DateTime jetzt) => !jetzt.isBefore(start) && jetzt.isBefore(ende);
  Duration get dauer => ende.difference(start);
}

/// Art eines Events (grob, nach dem Namen) – für Symbol und Erklärung
({String name, String erkl}) eventArt(String name) {
  final n = name.toLowerCase();
  if (RegExp(r'(tavern|chamber|portal|summon|black friday|exchange)').hasMatch(n)) {
    return (name: tx('Beschwörung', 'Summon'), erkl: tx('Portal / Beschwörung – neue Helden oder Kostüme ziehen', 'Portal / summon – pull new heroes or costumes'));
  }
  if (n.contains('alliance quest')) return (name: tx('Allianz-Quest', 'Alliance quest'), erkl: tx('Allianz-Event mit eigenen Regeln', 'Alliance event with special rules'));
  if (n.contains('titan')) return (name: 'Titan', erkl: tx('Besonderer Titan für die Allianz', 'Special titan for the alliance'));
  if (n.contains('war')) return (name: tx('Krieg', 'War'), erkl: tx('Kriegs-Event', 'War event'));
  if (RegExp(r'(league|contest|tournament|coach)').hasMatch(n)) {
    return (name: tx('Wettbewerb', 'Competition'), erkl: tx('Wettbewerb / Turnier / Liga', 'Competition / tournament / league'));
  }
  if (n.contains('tower')) return (name: tx('Turm', 'Tower'), erkl: tx('Turm-Event mit vielen Stufen', 'Tower event with many floors'));
  return (name: 'Event', erkl: tx('Herausforderung / Event mit eigenen Stufen', 'Challenge / event with its own stages'));
}

class NewsStand {
  final List<NewsArtikel> artikel;
  final List<EventTermin> termine;
  final List<String> regeln;
  final String stand;
  final bool ausCache;
  final String? fehler;
  const NewsStand(this.artikel, this.stand,
      {this.termine = const [], this.regeln = const [], this.ausCache = false, this.fehler});
}

class NewsDienst {
  static const quelle = 'https://raw.githubusercontent.com/$githubRepo/main/news/news.json';
  static const _cacheKey = 'news_cache';
  static const _gesehenKey = 'news_gesehen';

  static NewsStand _parsen(String text, {bool ausCache = false, String? fehler}) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final l = [for (final a in (j['artikel'] as List? ?? const [])) NewsArtikel.ausJson(a as Map<String, dynamic>)]
      ..sort((a, b) => b.datum.compareTo(a.datum));
    final termine = <EventTermin>[];
    for (final x in (j['kalender'] as List? ?? const [])) {
      try {
        termine.add(EventTermin.ausJson(x as Map<String, dynamic>));
      } catch (_) {}
    }
    termine.sort((a, b) => a.start.compareTo(b.start));
    final regeln = [for (final x in (j['regeln'] as List? ?? const [])) x as String];
    final regelnDe = [for (final x in (j['regeln_de'] as List? ?? const [])) x as String];
    return NewsStand(l, (j['stand'] ?? '') as String,
        termine: termine,
        regeln: !Sprache.en && regelnDe.length == regeln.length ? regelnDe : regeln,
        ausCache: ausCache,
        fehler: fehler);
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
