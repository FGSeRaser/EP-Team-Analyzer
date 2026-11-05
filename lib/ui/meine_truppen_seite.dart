// E&P Team-Analyzer – eigene Truppen eintragen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/truppen.dart';
import '../daten/truppen_besitz.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

const List<String> truppenTypen = ['mana', 'krit', 'magie', 'styx', 'ninja', 'leg', 'normal'];

String truppenTypName(String typ, TruppenWissen w) => switch (typ) {
      'leg' => tx('Legendär (5★)', 'Legendary (5★)'),
      'normal' => tx('Normal (1–3★)', 'Normal (1–3★)'),
      _ => w.epischNach(typ)?.label ?? typ,
    };

class MeineTruppenSeite extends StatelessWidget {
  final Datenbank db;
  const MeineTruppenSeite({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sammlung = SammlungScope.of(context);
    final w = truppenVon(db);
    final truppen = sammlung.truppen;
    return Scaffold(
      appBar: AppBar(title: Text(tx('Meine Truppen', 'My troops'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => truppeBearbeiten(context, db, null),
        icon: const Icon(Icons.add),
        label: Text(tx('Truppe hinzufügen', 'Add troop')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tx(
                'Trag hier deine Truppen aus der Kaserne ein. Der Team-Builder gibt dann jedem Helden die passende Truppe seiner Farbe – jede Truppe einmal pro Team.',
                'Enter your troops from the barracks. The team builder then gives every hero a fitting troop of its color – each troop once per team.')),
          ),
          if (truppen.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(tx('Noch keine Truppen eingetragen.', 'No troops added yet.'),
                  textAlign: TextAlign.center, style: t.textTheme.titleMedium),
            ),
          for (final farbe in elementFarben.keys)
            if (truppen.any((x) => x.farbe == farbe))
              Abschnitt(elementName(farbe), icon: Icons.shield, kinder: [
                for (final tr in truppen.where((x) => x.farbe == farbe).toList()
                  ..sort((a, b) => b.level.compareTo(a.level)))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: elementFarbe(farbe), radius: 14,
                        child: Text('${tr.level}', style: const TextStyle(fontSize: 11, color: Colors.black))),
                    title: Text(tr.typName(w)),
                    subtitle: Text([
                      'Level ${tr.level}',
                      if (tr.manaProzent(w) > 0) 'Mana +${tr.manaProzent(w)} %',
                      if (tr.kritProzent(w) > 0) '${tx('Krit', 'Crit')} ${tr.kritProzent(w)} %',
                      if (tr.umgehenProzent(w) > 0) '${tx('Umgehen', 'Bypass')} ${tr.umgehenProzent(w)} %',
                      if (tr.typ == 'leg' && tr.legName != null) _legKlassen(w, tr.legName!),
                      if (tr.anzahl > 1) '×${tr.anzahl}',
                    ].join(' · ')),
                    onTap: () => truppeBearbeiten(context, db, tr),
                  ),
              ]),
        ],
      ),
    );
  }

  static String _legKlassen(TruppenWissen w, String name) {
    final l = w.legendaer.where((x) => x.name == name).toList();
    if (l.isEmpty) return '';
    return '${w.klasseName(l.first.klasse1)}/${w.klasseName(l.first.klasse2)}';
  }
}

/// Liefert die gespeicherte Truppe (oder null bei Abbruch)
Future<EigeneTruppe?> truppeBearbeiten(BuildContext context, Datenbank db, EigeneTruppe? vorhanden, {String? farbe}) {
  return showModalBottomSheet<EigeneTruppe>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TruppenSheet(db: db, vorhanden: vorhanden, farbe: farbe),
  );
}

class _TruppenSheet extends StatefulWidget {
  final Datenbank db;
  final EigeneTruppe? vorhanden;
  final String? farbe;
  const _TruppenSheet({required this.db, this.vorhanden, this.farbe});

  @override
  State<_TruppenSheet> createState() => _TruppenSheetState();
}

class _TruppenSheetState extends State<_TruppenSheet> {
  late EigeneTruppe _t;

  @override
  void initState() {
    super.initState();
    final v = widget.vorhanden;
    _t = v == null
        ? EigeneTruppe(
            id: DateTime.now().microsecondsSinceEpoch.toString(), farbe: widget.farbe ?? 'rot', typ: 'mana', level: 1)
        : EigeneTruppe(
            id: v.id,
            farbe: v.farbe,
            typ: v.typ,
            legName: v.legName,
            sterne: v.sterne,
            level: v.level,
            anzahl: v.anzahl,
          );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final w = truppenVon(widget.db);
    final maxLv = EigeneTruppe.maxLevel(_t.typ, _t.sterne);
    if (_t.level > maxLv) _t.level = maxLv;
    final sammlung = SammlungScope.lesen(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(widget.vorhanden == null ? tx('Truppe hinzufügen', 'Add troop') : tx('Truppe bearbeiten', 'Edit troop'),
              style: t.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(tx('Farbe', 'Color')),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final f in elementFarben.keys)
              ChoiceChip(
                avatar: CircleAvatar(backgroundColor: elementFarben[f], radius: 7),
                label: Text(elementName(f)),
                selected: _t.farbe == f,
                onSelected: (_) => setState(() => _t.farbe = f),
              ),
          ]),
          const SizedBox(height: 12),
          Text(tx('Art', 'Type')),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final typ in truppenTypen)
              ChoiceChip(
                label: Text(truppenTypName(typ, w)),
                selected: _t.typ == typ,
                onSelected: (_) => setState(() {
                  _t.typ = typ;
                  _t.sterne = typ == 'leg' ? 5 : (typ == 'normal' ? 3 : 4);
                  if (typ == 'leg') _t.legName ??= w.legendaer.first.name;
                }),
              ),
          ]),
          if (_t.typ == 'leg') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _t.legName ?? w.legendaer.first.name,
              isExpanded: true,
              decoration: InputDecoration(labelText: tx('Legendäre Truppe', 'Legendary troop'), border: const OutlineInputBorder()),
              items: [
                for (final l in w.legendaer)
                  DropdownMenuItem(
                    value: l.name,
                    child: Text('${l.name} (${w.klasseName(l.klasse1)}/${w.klasseName(l.klasse2)})',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _t.legName = v),
            ),
          ],
          if (_t.typ == 'normal') ...[
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1★')),
                ButtonSegment(value: 2, label: Text('2★')),
                ButtonSegment(value: 3, label: Text('3★')),
              ],
              selected: {_t.sterne.clamp(1, 3)},
              onSelectionChanged: (v) => setState(() => _t.sterne = v.first),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            SizedBox(width: 90, child: Text('Level ${_t.level}')),
            Expanded(
              child: Slider(
                value: _t.level.toDouble().clamp(1.0, maxLv.toDouble()),
                min: 1,
                max: maxLv.toDouble(),
                divisions: maxLv - 1,
                label: '${_t.level}',
                onChanged: (v) => setState(() => _t.level = v.round()),
              ),
            ),
          ]),
          Row(children: [
            SizedBox(width: 90, child: Text(tx('Anzahl', 'Count'))),
            IconButton(
              onPressed: _t.anzahl > 1 ? () => setState(() => _t.anzahl--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${_t.anzahl}', style: t.textTheme.titleMedium),
            IconButton(onPressed: () => setState(() => _t.anzahl++), icon: const Icon(Icons.add_circle_outline)),
          ]),
          if (_t.manaProzent(w) > 0 || _t.kritProzent(w) > 0 || _t.umgehenProzent(w) > 0)
            Text(
              [
                if (_t.manaProzent(w) > 0) 'Mana +${_t.manaProzent(w)} %',
                if (_t.kritProzent(w) > 0) '${tx('Krit', 'Crit')} ${_t.kritProzent(w)} %',
                if (_t.umgehenProzent(w) > 0) '${tx('Umgehen', 'Bypass')} ${_t.umgehenProzent(w)} %',
              ].join(' · '),
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.primary),
            ),
          const SizedBox(height: 16),
          Row(children: [
            if (widget.vorhanden != null)
              TextButton(
                onPressed: () async {
                  await sammlung.truppeEntfernen(_t.id);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(tx('Entfernen', 'Remove'), style: const TextStyle(color: Colors.redAccent)),
              ),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                await sammlung.truppeSpeichern(_t);
                if (context.mounted) Navigator.pop(context, _t);
              },
              child: Text(tx('Speichern', 'Save')),
            ),
          ]),
        ]),
      ),
    );
  }
}
