// E&P Team-Analyzer – Screenshots laden und Erkennung im Hintergrund starten
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'erkennung.dart';
import 'kartentext.dart';

/// Ein geladener Screenshot (verkleinert auf Arbeitsbreite)
class Screenshot {
  final ui.Image anzeige;
  final Bild bild;

  /// Dateipfad (für die Texterkennung) und Breite des Originalbilds
  final String? pfad;
  final int originalBreite;
  const Screenshot(this.anzeige, this.bild, {this.pfad, this.originalBreite = 0});
}

class ReferenzDaten {
  final List<String> ids;
  final List<String> trainer;
  final Uint8List roh;
  const ReferenzDaten(this.ids, this.trainer, this.roh);

  static ReferenzDaten? _cache;

  static Future<ReferenzDaten> laden() async {
    if (_cache != null) return _cache!;
    final meta = jsonDecode(await rootBundle.loadString('assets/data/portraits.json')) as Map<String, dynamic>;
    final bin = await rootBundle.load('assets/data/portraits.bin');
    _cache = ReferenzDaten(
      List<String>.from(meta['ids'] as List),
      List<String>.from(meta['trainer'] as List? ?? const []),
      bin.buffer.asUint8List(bin.offsetInBytes, bin.lengthInBytes),
    );
    return _cache!;
  }
}

Future<Screenshot> screenshotLaden(Uint8List bytes, {String? pfad}) async {
  final puffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final beschreibung = await ui.ImageDescriptor.encoded(puffer);
  final originalBreite = beschreibung.width;
  beschreibung.dispose();
  puffer.dispose();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: arbeitsbreite);
  final frame = await codec.getNextFrame();
  final img = frame.image;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (data == null) throw Exception('Bild konnte nicht gelesen werden');
  final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  return Screenshot(
    img,
    Bild(Uint8List.fromList(rgba), img.width, img.height),
    pfad: pfad,
    originalBreite: originalBreite,
  );
}

/// Texterkennung (ML Kit, offline auf dem Handy). Liefert Zeilen in Arbeitsbild-Koordinaten.
/// Klappt sie nicht (z. B. altes Gerät), gibt es einfach keine Texte – die Porträts reichen auch.
Future<List<TextZeile>> textLesen(Screenshot s) async {
  if (s.pfad == null || s.originalBreite == 0) return const [];
  final erkenner = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final erg = await erkenner.processImage(InputImage.fromFilePath(s.pfad!));
    final f = s.bild.w / s.originalBreite;
    final out = <TextZeile>[];
    for (final block in erg.blocks) {
      for (final zeile in block.lines) {
        final r = zeile.boundingBox;
        out.add(TextZeile(zeile.text, r.left * f, r.top * f, r.right * f, r.bottom * f));
      }
    }
    return out;
  } catch (_) {
    return const [];
  } finally {
    await erkenner.close();
  }
}

/// Erkennung im Hintergrund (eigener Isolate), damit die App flüssig bleibt
Future<ErkennungsErgebnis> erkennen(Screenshot s, {Raster? raster}) async {
  final ref = await ReferenzDaten.laden();
  return compute(
    erkennungAusfuehren,
    ErkennungsAuftrag(s.bild.rgba, s.bild.w, s.bild.h, ref.ids, ref.trainer, ref.roh, raster),
  );
}
