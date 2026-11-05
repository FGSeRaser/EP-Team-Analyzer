// E&P Team-Analyzer – Gegner-Analyse: welche eigenen Helden gegen dieses Team?
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../daten/analyse.dart';
import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/team_builder.dart';
import '../erkennung/kartentext.dart';
import '../erkennung/screenshot.dart';
import 'held_detail.dart';
import 'helden_liste.dart';
import 'team_builder_seite.dart';
import 'team_karte.dart';
import 'widgets.dart';

class GegnerSeite extends StatefulWidget {
  final Datenbank db;
  const GegnerSeite({super.key, required this.db});

  @override
  State<GegnerSeite> createState() => _GegnerSeiteState();
}

class _GegnerSeiteState extends State<GegnerSeite> {
  final List<Held?> _gegner = List<Held?>.filled(5, null);
  final Map<int, int> _staerke = {}; // Platz -> Stärke aus Screenshot
  bool _laeuft = false;
  String? _meldung;
  List<TeamVorschlag>? _ergebnis;

  static List<String> get _pos => [
        tx('Flanke', 'Flank'),
        tx('Flügel', 'Wing'),
        'Tank',
        tx('Flügel', 'Wing'),
        tx('Flanke', 'Flank'),
      ];

  Future<void> _waehle(int i) async {
    final h = await Navigator.push<Held>(
      context,
      MaterialPageRoute(builder: (_) => HeldenListe(db: widget.db, auswahl: true, titel: tx('Gegner wählen', 'Pick enemy'))),
    );
    if (h != null) {
      setState(() {
        _gegner[i] = h;
        _staerke.remove(i);
        _ergebnis = null;
      });
    }
  }

  Future<void> _screenshot() async {
    final datei = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (datei == null) return;
    setState(() {
      _laeuft = true;
      _meldung = null;
    });
    try {
      final shot = await screenshotLaden(await datei.readAsBytes(), pfad: datei.path);
      final texteF = textLesen(shot);
      final erg = await erkennen(shot);
      final texte = await texteF;
      final ref = await ReferenzDaten.laden();
      final trainer = ref.trainer.toSet();
      // Die 5 sichersten Treffer, von links nach rechts
      final treffer = erg.treffer.where((t) => !trainer.contains(t.kandidaten.first.id)).toList()
        ..sort((a, b) => b.kandidaten.first.wert.compareTo(a.kandidaten.first.wert));
      final beste = treffer.take(5).toList()
        ..sort((a, b) {
          final z = a.zelle.zeile.compareTo(b.zelle.zeile);
          return z != 0 ? z : a.zelle.spalte.compareTo(b.zelle.spalte);
        });
      setState(() {
        for (var i = 0; i < 5; i++) {
          _gegner[i] = null;
          _staerke.remove(i);
        }
        for (var i = 0; i < beste.length; i++) {
          final t = beste[i];
          _gegner[i] = widget.db.nachId[t.kandidaten.first.id];
          final k = kartenTextLesen(t.zelle, erg.raster, texte);
          if (k.staerke != null) _staerke[i] = k.staerke!;
        }
        _meldung = beste.length < 5
            ? tx('Nur ${beste.length} Helden erkannt – fehlende bitte antippen und wählen.',
                'Only ${beste.length} heroes recognized – tap the empty slots to pick them.')
            : tx('Erkannt – bitte kurz prüfen. Antippen zum Ändern.', 'Recognized – please check. Tap to change.');
        _ergebnis = null;
      });
    } catch (e) {
      setState(() => _meldung = tx('Screenshot konnte nicht gelesen werden: $e', 'Could not read screenshot: $e'));
    }
    if (mounted) setState(() => _laeuft = false);
  }

  Future<void> _berechnen() async {
    final gegner = _gegner.whereType<Held>().toList();
    final p = eigenerPool(context, widget.db);
    if (gegner.isEmpty || p.pool.length < 5) return;
    setState(() {
      _laeuft = true;
      _ergebnis = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final gegnerKraft = <String, int>{
      for (final e in _staerke.entries)
        if (_gegner[e.key] != null) _gegner[e.key]!.id: e.value,
    };
    final b = TeamBuilder(Analyse(widget.db), kraftVon: p.kraft, gegnerKraft: gegnerKraft);
    final erg = b.baue(p.pool, Modus.gegner, gegner: gegner);
    if (!mounted) return;
    setState(() {
      _ergebnis = erg;
      _laeuft = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final gegner = _gegner.whereType<Held>().toList();
    final erg = _ergebnis;
    final tank = _gegner[2];
    final stark = tank == null ? null : starkGegen(tank.element);

    return Scaffold(
      appBar: AppBar(title: Text(tx('Gegner-Analyse', 'Enemy analysis'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(tx(
                'Gegnerteam per Screenshot einlesen oder die 5 Plätze antippen. Danach sucht die App aus deinen Helden die Teams mit der besten Chance.',
                'Load the enemy team from a screenshot or tap the 5 slots. Then the app finds your teams with the best chance.')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: _laeuft ? null : _screenshot,
              icon: const Icon(Icons.photo_camera),
              label: Text(tx('Screenshot vom Gegnerteam', 'Enemy team screenshot')),
            ),
          ),
          if (_meldung != null)
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(_meldung!, style: t.textTheme.bodySmall)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Row(children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _waehle(i),
                    onLongPress: _gegner[i] == null
                        ? null
                        : () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => HeldDetail(db: widget.db, held: _gegner[i]!))),
                    child: Column(children: [
                      _gegner[i] == null
                          ? Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: t.colorScheme.outline),
                              ),
                              child: const Icon(Icons.add),
                            )
                          : HeldBild(_gegner[i]!, groesse: 56),
                      const SizedBox(height: 3),
                      Text(_gegner[i]?.nameL ?? _pos[i],
                          style: t.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (_staerke[i] != null) Text('${_staerke[i]}', style: t.textTheme.labelSmall),
                      Text(_pos[i], style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.primary)),
                    ]),
                  ),
                ),
            ]),
          ),
          if (tank != null && stark != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                CircleAvatar(backgroundColor: elementFarbe(stark), radius: 8),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(tx('Tank ${tank.nameL} ist ${elementName(tank.element)} – stark dagegen: ${elementName(stark)}',
                      'Tank ${tank.nameL} is ${elementName(tank.element)} – strong against it: ${elementName(stark)}')),
                ),
              ]),
            ),
          if (gegner.isNotEmpty) _gefahren(t, gegner),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: gegner.isEmpty || _laeuft ? null : _berechnen,
              icon: const Icon(Icons.psychology),
              label: Text(tx('Beste Teams gegen diesen Gegner', 'Best teams against this enemy')),
            ),
          ),
          if (_laeuft) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (erg != null && erg.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tx('Trag zuerst mindestens 5 eigene Helden unter „Meine“ ein.',
                  'First add at least 5 of your heroes under "Mine".')),
            ),
          if (erg != null)
            for (var i = 0; i < erg.length; i++)
              TeamKarte(
                db: widget.db,
                v: erg[i],
                titel: i == 0 ? tx('Bester Konter', 'Best counter') : tx('Alternative $i', 'Alternative $i'),
              ),
          if (erg != null && erg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tx('Die Prozentzahl ist eine Schätzung aus Stärke, Farbvorteil (vor allem gegen den Tank), '
                        'Kontern gegen die Effekte des Gegners und Heilung – kein Kampfsimulator. '
                        'Glück beim Steinefallen und Truppen/Embleme des Gegners kann die App nicht kennen.',
                    'The percentage is an estimate from power, color advantage (especially vs the tank), '
                        'counters to the enemy effects and healing – not a battle simulator. '
                        'Tile luck and the enemy troops/emblems are unknown to the app.'),
                style: t.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _gefahren(ThemeData t, List<Held> gegner) {
    final db = widget.db;
    final gefahren = <String, List<Held>>{};
    for (final key in wichtigeBedrohungen) {
      final traeger = gegner.where((g) => g.effekte.contains(key)).toList();
      if (traeger.isNotEmpty) gefahren[key] = traeger;
    }
    if (gefahren.isEmpty) return const SizedBox.shrink();
    return Abschnitt(tx('Das kann der Gegner', 'What the enemy brings'), icon: Icons.warning_amber, kinder: [
      for (final e in gefahren.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${db.bedrohungName(e.key)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: e.value.map((h) => h.nameL).join(', ')),
          ])),
        ),
    ]);
  }
}
