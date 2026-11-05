// E&P Team-Analyzer – Stufe, Level, Limit Break und Talent eines eigenen Helden
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/sammlung.dart';
import '../daten/werte.dart';
import 'held_detail.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

Future<void> besitzBearbeiten(BuildContext context, Datenbank db, Held held) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BesitzSheet(db: db, held: held),
  );
}

class _BesitzSheet extends StatefulWidget {
  final Datenbank db;
  final Held held;
  const _BesitzSheet({required this.db, required this.held});

  @override
  State<_BesitzSheet> createState() => _BesitzSheetState();
}

class _BesitzSheetState extends State<_BesitzSheet> {
  late Besitz _b;
  late bool _neu;

  @override
  void initState() {
    super.initState();
    final vorhanden = SammlungScope.lesen(context).besitz(widget.held.id);
    _neu = vorhanden == null;
    final v = vorhanden ?? Besitz.max(widget.held);
    // Kopie, damit "Abbrechen" nichts verändert
    _b = Besitz(
      id: v.id,
      anzahl: v.anzahl,
      stufe: v.stufe,
      level: v.level,
      lb: v.lb,
      talent: v.talent,
      staerke: v.staerke,
      notiz: v.notiz,
    );
  }

  void _korrigieren() {
    final h = widget.held;
    final stufen = stufenAnzahl(h.sterne);
    _b.stufe = _b.stufe.clamp(1, stufen);
    if (_b.stufe < stufen) _b.lb = 0;
    _b.level = _b.level.clamp(1, maxLevel(h.sterne, _b.stufe, _b.lb));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final h = widget.held;
    final stufen = stufenAnzahl(h.sterne);
    final maxLb = maxLbAnzahl(h.sterne);
    final maxLv = maxLevel(h.sterne, _b.stufe, _b.lb);
    final w = _b.werte(h);
    final sammlung = SammlungScope.lesen(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              HeldBild(h, groesse: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.anzeigeName, style: t.textTheme.titleLarge),
                  Sterne(h.sterne),
                ]),
              ),
              IconButton(
                tooltip: 'Details',
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HeldDetail(db: widget.db, held: h)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(width: 110, child: Text(tx('Anzahl', 'Count'))),
              IconButton(
                onPressed: _b.anzahl > 1 ? () => setState(() => _b.anzahl--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${_b.anzahl}', style: t.textTheme.titleMedium),
              IconButton(
                onPressed: () => setState(() => _b.anzahl++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
            Text(tx('Aufstiegsstufe', 'Ascension')),
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: [for (var s = 1; s <= stufen; s++) ButtonSegment(value: s, label: Text('$s'))],
              selected: {_b.stufe},
              onSelectionChanged: (v) => setState(() {
                _b.stufe = v.first;
                _korrigieren();
              }),
            ),
            if (maxLb > 0) ...[
              const SizedBox(height: 10),
              const Text('Limit Break'),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: [
                  for (var l = 0; l <= maxLb; l++) ButtonSegment(value: l, label: Text(l == 0 ? tx('Keiner', 'None') : 'LB$l')),
                ],
                selected: {_b.lb},
                onSelectionChanged: _b.stufe < stufen
                    ? null
                    : (v) => setState(() {
                          _b.lb = v.first;
                          _b.level = maxLevel(h.sterne, _b.stufe, _b.lb);
                        }),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              SizedBox(width: 110, child: Text('Level ${_b.level}')),
              Expanded(
                child: Slider(
                  value: _b.level.toDouble().clamp(1.0, maxLv.toDouble()),
                  min: 1,
                  max: maxLv.toDouble(),
                  divisions: maxLv > 1 ? maxLv - 1 : null,
                  label: '${_b.level}',
                  onChanged: maxLv > 1 ? (v) => setState(() => _b.level = v.round()) : null,
                ),
              ),
            ]),
            if (h.sterne >= 3)
              Row(children: [
                SizedBox(width: 110, child: Text('Talent +${_b.talent}')),
                Expanded(
                  child: Slider(
                    value: _b.talent.toDouble(),
                    min: 0,
                    max: 25,
                    divisions: 25,
                    label: '+${_b.talent}',
                    onChanged: (v) => setState(() => _b.talent = v.round()),
                  ),
                ),
              ]),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _wert(tx('Angriff', 'Attack'), w.angriff),
                    _wert(tx('Verteid.', 'Defense'), w.verteidigung),
                    _wert(tx('Leben', 'Health'), w.leben),
                    _wert(tx('Kraft', 'Power'), w.kraft),
                  ],
                ),
              ),
            ),
            Text(
              _b.staerke != null
                  ? tx('Berechnet ohne Embleme/Kostüm · Stärke laut Spiel: ${_b.staerke}', 'Calculated without emblems/costume · in-game power: ${_b.staerke}')
                  : tx('Ohne Embleme und Kostümbonus.', 'Without emblems and costume bonus.'),
              style: t.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _b.stufe = stufen;
                  _b.lb = 0;
                  _b.level = maxLevel(h.sterne, stufen, 0);
                }),
                child: Text(tx('Auf Max', 'Set max')),
              ),
              const Spacer(),
              if (!_neu)
                TextButton(
                  onPressed: () async {
                    await sammlung.entfernen(h.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(tx('Entfernen', 'Remove'), style: TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  _korrigieren();
                  await sammlung.aktualisieren(_b);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(_neu ? tx('Hinzufügen', 'Add') : tx('Speichern', 'Save')),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _wert(String name, int v) => Column(children: [
        Text('$v', style: Theme.of(context).textTheme.titleMedium),
        Text(name, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
