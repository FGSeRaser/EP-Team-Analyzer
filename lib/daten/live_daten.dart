// E&P Team-Analyzer – Heldendaten live von GitHub, ohne App-Update
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Ein GitHub-Workflow baut die Daten (Helden, Porträts, Talente) täglich neu und
// schreibt assets/data/stand.json mit Version und Prüfsummen. Die App vergleicht
// beim Start die Version, lädt nur geänderte Dateien in ihren eigenen Ordner und
// nimmt diese ab dann statt der mitgelieferten. Nach einem App-Update gewinnt
// automatisch wieder die neuere Fassung.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'updater.dart' show githubRepo;

class LiveDaten {
  static const quelle = 'https://raw.githubusercontent.com/$githubRepo/main/assets/data/';
  static const dateien = ['helden.json', 'portraits.json', 'portraits.bin', 'talente.json'];

  static Directory? _ordner;
  static bool? _lokalGilt;

  static Future<Directory> _verzeichnis() async =>
      _ordner ??= Directory('${(await getApplicationSupportDirectory()).path}/daten');

  static Future<Map<String, dynamic>> _assetStand() async {
    try {
      return jsonDecode(await rootBundle.loadString('assets/data/stand.json')) as Map<String, dynamic>;
    } catch (_) {
      return const {'version': ''};
    }
  }

  static Future<Map<String, dynamic>?> _lokalerStand() async {
    try {
      final f = File('${(await _verzeichnis()).path}/stand.json');
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Gilt der heruntergeladene Stand (neuer als der mitgelieferte und vollständig)?
  static Future<bool> _lokalAktiv() async {
    if (_lokalGilt != null) return _lokalGilt!;
    final lokal = await _lokalerStand();
    final asset = await _assetStand();
    var ok = lokal != null && (lokal['version'] as String? ?? '').compareTo(asset['version'] as String? ?? '') > 0;
    if (ok) {
      final dir = await _verzeichnis();
      for (final d in dateien) {
        if (!await File('${dir.path}/$d').exists()) ok = false;
      }
    }
    return _lokalGilt = ok;
  }

  /// Aktuelle Datenversion (z. B. "2026-11-06T16:10Z")
  static Future<String> version() async {
    if (await _lokalAktiv()) return ((await _lokalerStand())?['version'] ?? '') as String;
    return ((await _assetStand())['version'] ?? '') as String;
  }

  static Future<String> text(String name) async {
    if (await _lokalAktiv()) {
      try {
        return await File('${(await _verzeichnis()).path}/$name').readAsString();
      } catch (_) {}
    }
    return rootBundle.loadString('assets/data/$name');
  }

  static Future<Uint8List> bytes(String name) async {
    if (await _lokalAktiv()) {
      try {
        return await File('${(await _verzeichnis()).path}/$name').readAsBytes();
      } catch (_) {}
    }
    final b = await rootBundle.load('assets/data/$name');
    return b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
  }

  static Future<Uint8List> _holen(HttpClient c, String name) async {
    final req = await c.getUrl(Uri.parse('$quelle$name?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'));
    final res = await req.close().timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode} bei $name');
    final b = BytesBuilder(copy: false);
    await for (final teil in res) {
      b.add(teil);
    }
    return b.takeBytes();
  }

  /// Auf GitHub nach neueren Daten schauen und sie herunterladen.
  /// Liefert die neue Version, wenn etwas geladen wurde, sonst null.
  static Future<String?> aktualisieren() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final fern = jsonDecode(utf8.decode(await _holen(c, 'stand.json'))) as Map<String, dynamic>;
      final neu = (fern['version'] ?? '') as String;
      if (neu.isEmpty || neu.compareTo(await version()) <= 0) return null;

      final dir = await _verzeichnis();
      await dir.create(recursive: true);
      final lokal = await _lokalAktiv() ? await _lokalerStand() : null;
      final asset = await _assetStand();
      final summen = (fern['dateien'] as Map?)?.cast<String, dynamic>() ?? const {};
      final lokalSummen = ((lokal ?? asset)['dateien'] as Map?)?.cast<String, dynamic>() ?? const {};

      for (final d in dateien) {
        final ziel = File('${dir.path}/$d');
        // Unveränderte Datei: aus dem bisherigen Stand übernehmen statt neu laden
        if (summen[d] != null && summen[d] == lokalSummen[d]) {
          if (lokal != null && await ziel.exists()) continue;
          await ziel.writeAsBytes(await _ausAsset(d), flush: true);
          continue;
        }
        final daten = await _holen(c, d);
        final tmp = File('${ziel.path}.neu');
        await tmp.writeAsBytes(daten, flush: true);
        await tmp.rename(ziel.path);
      }
      // stand.json zuletzt: erst dann gilt der neue Stand als vollständig
      await File('${dir.path}/stand.json').writeAsString(jsonEncode(fern), flush: true);
      _lokalGilt = null;
      return neu;
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  static Future<Uint8List> _ausAsset(String name) async {
    final b = await rootBundle.load('assets/data/$name');
    return b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
  }

  /// Zwischenspeicher der Lader leeren (nach einem Daten-Update)
  static final List<void Function()> _beimWechsel = [];
  static void beimWechsel(void Function() f) => _beimWechsel.add(f);
  static void wechselMelden() {
    for (final f in _beimWechsel) {
      f();
    }
  }
}
