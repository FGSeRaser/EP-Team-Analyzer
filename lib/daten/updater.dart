// E&P Team-Analyzer – Update-Funktion: neue APK von GitHub holen und installieren
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Jeder Build auf GitHub legt ein Release "build-<Nummer>" mit der APK an.
// Die App vergleicht diese Nummer mit ihrer eigenen Build-Nummer.

import 'dart:convert';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String githubRepo = 'FGSeRaser/EP-Team-Analyzer';

class UpdateInfo {
  final int build;
  final String titel;
  final String notizen;
  final String url;
  final int groesse; // Bytes
  final int eigenerBuild;
  final String eigeneVersion;
  const UpdateInfo({
    required this.build,
    required this.titel,
    required this.notizen,
    required this.url,
    required this.groesse,
    required this.eigenerBuild,
    required this.eigeneVersion,
  });
  bool get neuer => build > eigenerBuild;
}

class Updater {
  static const _letztePruefung = 'update_letzte_pruefung';
  static const _autoSchluessel = 'update_auto';

  static Future<({String version, int build})> eigeneVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, build: int.tryParse(info.buildNumber) ?? 0);
  }

  static Future<bool> autoAn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_autoSchluessel) ?? true;
  }

  static Future<void> autoSetzen(bool an) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_autoSchluessel, an);
  }

  /// Fragt GitHub nach dem neuesten Release. Liefert null bei Fehler / ohne Internet.
  static Future<UpdateInfo?> pruefen() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'));
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'EP-Team-Analyzer-App')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '') as String;
      final build = int.tryParse(RegExp(r'(\d+)$').firstMatch(tag)?.group(1) ?? '') ?? 0;
      Map<String, dynamic>? apk;
      for (final a in (j['assets'] as List? ?? const [])) {
        final m = a as Map<String, dynamic>;
        if ((m['name'] as String? ?? '').toLowerCase().endsWith('.apk')) {
          apk = m;
          break;
        }
      }
      if (apk == null) return null;
      final eigene = await eigeneVersion();
      final p = await SharedPreferences.getInstance();
      await p.setInt(_letztePruefung, DateTime.now().millisecondsSinceEpoch);
      return UpdateInfo(
        build: build,
        titel: (j['name'] ?? tag) as String,
        notizen: ((j['body'] ?? '') as String)
            .split('\n')
            .where((z) => !z.startsWith('Co-Authored-By') && !z.startsWith('Claude-Session'))
            .join('\n')
            .trim(),
        url: apk['browser_download_url'] as String,
        groesse: (apk['size'] as num?)?.toInt() ?? 0,
        eigenerBuild: eigene.build,
        eigeneVersion: eigene.version,
      );
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Beim App-Start: höchstens einmal pro Tag automatisch prüfen
  static Future<UpdateInfo?> pruefenWennFaellig() async {
    if (!await autoAn()) return null;
    final p = await SharedPreferences.getInstance();
    final zuletzt = p.getInt(_letztePruefung) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - zuletzt < const Duration(hours: 20).inMilliseconds) {
      return null;
    }
    final info = await pruefen();
    return (info != null && info.neuer) ? info : null;
  }

  /// APK herunterladen; [fortschritt] bekommt 0..1
  static Future<File> herunterladen(UpdateInfo info, void Function(double) fortschritt) async {
    final ordner = await getTemporaryDirectory();
    final datei = File('${ordner.path}/EP-Team-Analyzer-update.apk');
    if (await datei.exists()) await datei.delete();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse(info.url));
      req.headers.set(HttpHeaders.userAgentHeader, 'EP-Team-Analyzer-App');
      final res = await req.close(); // folgt der Weiterleitung von GitHub automatisch
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final gesamt = res.contentLength > 0 ? res.contentLength : info.groesse;
      final sink = datei.openWrite();
      var geladen = 0;
      await for (final teil in res) {
        sink.add(teil);
        geladen += teil.length;
        if (gesamt > 0) fortschritt(geladen / gesamt);
      }
      await sink.close();
      return datei;
    } finally {
      client.close();
    }
  }

  /// Öffnet den Android-Installer. Android fragt immer selbst nach ("Installieren").
  static Future<String?> installieren(File apk) async {
    final r = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
    return r.type == ResultType.done ? null : r.message;
  }
}
