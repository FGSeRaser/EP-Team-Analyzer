// E&P Team-Analyzer – Helden per Screenshot einlesen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../daten/datenbank.dart';
import '../daten/namen_suche.dart';
import '../erkennung/erkennung.dart';
import '../erkennung/kartentext.dart';
import '../erkennung/screenshot.dart';
import 'bestaetigung.dart';

class _Aufnahme {
  final Screenshot shot;
  ErkennungsErgebnis? ergebnis;
  List<TextZeile> texte = const [];
  bool laeuft = false;
  String? fehler;
  _Aufnahme(this.shot);
}

class EingabeScreenshot extends StatefulWidget {
  final Datenbank db;
  const EingabeScreenshot({super.key, required this.db});

  @override
  State<EingabeScreenshot> createState() => _EingabeScreenshotState();
}

class _EingabeScreenshotState extends State<EingabeScreenshot> {
  final List<_Aufnahme> _aufnahmen = [];
  bool _laedt = false;

  Future<void> _waehlen() async {
    final dateien = await ImagePicker().pickMultiImage();
    if (dateien.isEmpty) return;
    setState(() => _laedt = true);
    for (final d in dateien) {
      try {
        final s = await screenshotLaden(await d.readAsBytes(), pfad: d.path);
        final a = _Aufnahme(s);
        setState(() => _aufnahmen.add(a));
        // Texterkennung (Namen, Level, Stärke) parallel zur Porträt-Erkennung
        final texte = textLesen(s);
        await _erkennen(a);
        a.texte = await texte;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bild nicht lesbar: $e')));
        }
      }
    }
    if (mounted) setState(() => _laedt = false);
  }

  Future<void> _erkennen(_Aufnahme a, {Raster? raster}) async {
    setState(() {
      a.laeuft = true;
      a.fehler = null;
    });
    try {
      a.ergebnis = await erkennen(a.shot, raster: raster);
    } catch (e) {
      a.fehler = '$e';
    }
    if (mounted) setState(() => a.laeuft = false);
  }

  Future<void> _rasterAnpassen(_Aufnahme a) async {
    final r = a.ergebnis?.raster;
    if (r == null) return;
    final neu = await Navigator.push<Raster>(
      context,
      MaterialPageRoute(builder: (_) => RasterEditor(shot: a.shot, start: r)),
    );
    if (neu != null) await _erkennen(a, raster: neu);
  }

  Future<void> _pruefen() async {
    final funde = <Fund>[];
    final daten = await ReferenzDaten.laden();
    {
      final trainer = daten.trainer.toSet();
      for (var i = 0; i < _aufnahmen.length; i++) {
        final a = _aufnahmen[i];
        for (final t in a.ergebnis?.treffer ?? const <Treffer>[]) {
          // Trainer-Helden (zum Füttern) und unbekannte IDs überspringen
          if (trainer.contains(t.kandidaten.first.id)) continue;
          final kand = <Held>[];
          final werte = <double>[];
          for (final k in t.kandidaten) {
            final h = widget.db.nachId[k.id];
            if (h != null) {
              kand.add(h);
              werte.add(k.wert);
            }
          }
          if (kand.isEmpty) continue;
          final z = t.zelle;
          final text = kartenTextLesen(z, a.ergebnis!.raster, a.texte);
          final bestaetigt = _nachNamenSortieren(text.name, kand, werte);
          funde.add(Fund(
            quelle: 'Bild ${i + 1}, Reihe ${z.zeile + 1}',
            gruppe: i,
            bild: a.shot.anzeige,
            rect: Rect.fromLTRB(z.x0, z.y0, z.x1, z.y1),
            kandidaten: kand,
            werte: werte,
            textName: text.name,
            level: text.level,
            talent: text.talent,
            staerke: text.staerke,
            nameBestaetigt: bestaetigt,
          ));
        }
      }
      if (!mounted) return;
      if (funde.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Helden erkannt – Raster anpassen?')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BestaetigungSeite(
            db: widget.db,
            funde: funde,
            titel: 'Erkannte Helden',
            ausScreenshots: true,
          ),
        ),
      );
    }
  }

  /// Gelesenen Namen nutzen: passende Porträt-Kandidaten nach vorne holen.
  /// Steht der Name gar nicht unter den Bild-Kandidaten, kommen die Helden mit
  /// diesem Namen dazu (mit Wert 0 → als unsicher markiert).
  /// Liefert true, wenn Name und bestes Porträt zusammenpassen.
  bool _nachNamenSortieren(String? name, List<Held> kand, List<double> werte) {
    if (name == null || name.length < 3) return false;
    final q = normName(name);
    bool passt(Held h) {
      final n = normName(h.name);
      return n == q || levenshtein(n, q) <= (q.length <= 5 ? 1 : 2);
    }

    final idx = [for (var k = 0; k < kand.length; k++) if (passt(kand[k])) k];
    if (idx.isNotEmpty) {
      final vorne = [for (final k in idx) MapEntry(kand[k], werte[k])];
      final rest = [for (var k = 0; k < kand.length; k++) if (!idx.contains(k)) MapEntry(kand[k], werte[k])];
      kand
        ..clear()
        ..addAll([...vorne, ...rest].map((e) => e.key));
      werte
        ..clear()
        ..addAll([...vorne, ...rest].map((e) => e.value));
      return true;
    }
    final perName = sucheNamen(widget.db, name).where((h) => !h.kommend).toList();
    if (perName.isNotEmpty && passt(perName.first)) {
      kand.insertAll(0, perName);
      werte.insertAll(0, List<double>.filled(perName.length, 0));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final gesamt = _aufnahmen.fold<int>(0, (a, b) => a + (b.ergebnis?.treffer.length ?? 0));
    final beschaeftigt = _laedt || _aufnahmen.any((a) => a.laeuft);
    return Scaffold(
      appBar: AppBar(title: const Text('Screenshots einlesen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('So geht\'s', style: t.textTheme.titleMedium),
                const SizedBox(height: 6),
                const Text('1. Im Spiel die Heldenliste öffnen (Helden → alle Helden).\n'
                    '2. Screenshot machen, ein Stück weiterscrollen, nächster Screenshot …\n'
                    '3. Hier alle Screenshots auf einmal auswählen.\n'
                    '4. Die App findet das Raster selbst. Passt es nicht, über „Raster anpassen“ nachjustieren.\n'
                    '5. Ergebnis prüfen und übernehmen.'),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: beschaeftigt ? null : _waehlen,
            icon: const Icon(Icons.photo_library),
            label: Text(_aufnahmen.isEmpty ? 'Screenshots auswählen' : 'Weitere Screenshots'),
          ),
          if (beschaeftigt)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Erkenne Helden …'),
              ])),
            ),
          for (var i = 0; i < _aufnahmen.length; i++) _aufnahmeKarte(t, i, _aufnahmen[i]),
        ],
      ),
      floatingActionButton: gesamt == 0 || beschaeftigt
          ? null
          : FloatingActionButton.extended(
              onPressed: _pruefen,
              icon: const Icon(Icons.fact_check),
              label: Text('$gesamt Helden prüfen'),
            ),
    );
  }

  Widget _aufnahmeKarte(ThemeData t, int i, _Aufnahme a) {
    final erg = a.ergebnis;
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                'Bild ${i + 1}: ${a.laeuft ? 'wird erkannt …' : (a.fehler != null ? 'Fehler' : '${erg?.treffer.length ?? 0} Helden')}',
                style: t.textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: a.laeuft || erg == null ? null : () => _rasterAnpassen(a),
              child: const Text('Raster anpassen'),
            ),
            IconButton(
              tooltip: 'Entfernen',
              icon: const Icon(Icons.close),
              onPressed: a.laeuft ? null : () => setState(() => _aufnahmen.removeAt(i)),
            ),
          ]),
          if (a.fehler != null) Text(a.fehler!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 6),
          RasterVorschau(
            shot: a.shot,
            raster: erg?.raster,
            treffer: erg?.treffer ?? const [],
            hoehe: 320,
          ),
        ]),
      ),
    );
  }
}

/// Screenshot mit eingezeichnetem Raster (grün = Held erkannt)
class RasterVorschau extends StatelessWidget {
  final Screenshot shot;
  final Raster? raster;
  final List<Treffer> treffer;
  final double? hoehe;
  const RasterVorschau({super.key, required this.shot, this.raster, this.treffer = const [], this.hoehe});

  @override
  Widget build(BuildContext context) {
    final img = shot.anzeige;
    return LayoutBuilder(builder: (context, c) {
      var breite = c.maxWidth;
      var h = breite * img.height / img.width;
      final grenze = hoehe ?? (c.maxHeight.isFinite ? c.maxHeight : double.infinity);
      if (h > grenze) {
        h = grenze;
        breite = h * img.width / img.height;
      }
      return Center(
        child: SizedBox(
          width: breite,
          height: h,
          child: CustomPaint(painter: _RasterMaler(shot, raster, treffer)),
        ),
      );
    });
  }
}

class _RasterMaler extends CustomPainter {
  final Screenshot shot;
  final Raster? raster;
  final List<Treffer> treffer;
  _RasterMaler(this.shot, this.raster, this.treffer);

  @override
  void paint(Canvas canvas, Size size) {
    final img = shot.anzeige;
    final f = size.width / img.width;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final r = raster;
    if (r == null) return;
    final grau = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white54;
    final gruen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.greenAccent;
    final treffpunkte = {for (final t in treffer) '${t.zelle.zeile}/${t.zelle.spalte}'};
    for (final z in r.zellen(shot.bild.w, shot.bild.h)) {
      final rect = Rect.fromLTRB(z.x0 * f, z.y0 * f, z.x1 * f, z.y1 * f);
      canvas.drawRect(rect, treffpunkte.contains('${z.zeile}/${z.spalte}') ? gruen : grau);
    }
  }

  @override
  bool shouldRepaint(_RasterMaler alt) => alt.raster != raster || alt.treffer != treffer || alt.shot != shot;
}

/// Raster von Hand einstellen
class RasterEditor extends StatefulWidget {
  final Screenshot shot;
  final Raster start;
  const RasterEditor({super.key, required this.shot, required this.start});

  @override
  State<RasterEditor> createState() => _RasterEditorState();
}

class _RasterEditorState extends State<RasterEditor> {
  late Raster _r = widget.start;

  @override
  Widget build(BuildContext context) {
    final w = widget.shot.bild.w.toDouble();
    final h = widget.shot.bild.h.toDouble();
    final r = _r;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raster anpassen'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _r), child: const Text('Übernehmen')),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: RasterVorschau(shot: widget.shot, raster: r),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            const Text('Die Kästchen sollen genau auf den Gesichtern der Helden liegen.'),
            _regler('Abstand waagrecht', r.dx, w / 10, w / 2, (v) => _r = r.kopie(dx: v)),
            _regler('Abstand senkrecht', r.dy, h / 20, h / 2, (v) => _r = r.kopie(dy: v)),
            _regler('Größe', r.pw, r.dx * 0.4, r.dx, (v) => _r = r.kopie(pw: v)),
            _regler('Links', r.x0, 0, w, (v) => _r = r.kopie(x0: v)),
            _regler('Oben', r.y0, 0, h, (v) => _r = r.kopie(y0: v)),
          ]),
        ),
      ]),
    );
  }

  Widget _regler(String name, double wert, double min, double max, void Function(double) setzen) {
    final v = wert.clamp(min, max).toDouble();
    return Row(children: [
      SizedBox(width: 130, child: Text(name)),
      Expanded(
        child: Slider(
          value: v,
          min: min,
          max: max,
          onChanged: (x) => setState(() => setzen(x)),
        ),
      ),
    ]);
  }
}
