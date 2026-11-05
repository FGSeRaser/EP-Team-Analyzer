// E&P Team-Analyzer – eigene Truppen eintragen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/truppen.dart';
import '../daten/truppen_besitz.dart';
import '../erkennung/screenshot.dart';
import '../erkennung/truppen_text.dart';
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
      appBar: AppBar(title: Text(tx('Meine Truppen', 'My troops')), actions: [
        IconButton(
          tooltip: tx('Aus Screenshot übernehmen', 'Import from screenshot'),
          onPressed: () => truppenAusScreenshot(context, db),
          icon: const Icon(Icons.add_a_photo_outlined),
        ),
      ]),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => truppenAusScreenshot(context, db),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(tx('Truppen per Screenshot übernehmen', 'Import troops from a screenshot')),
            ),
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

/// Screenshot(s) aus der Kaserne wählen, Truppen erkennen, prüfen lassen und speichern
Future<void> truppenAusScreenshot(BuildContext context, Datenbank db) async {
  final dateien = await ImagePicker().pickMultiImage();
  if (dateien.isEmpty || !context.mounted) return;
  final w = truppenVon(db);
  final gefunden = <TruppenTreffer>[];
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    for (final d in dateien) {
      final shot = await screenshotLaden(await d.readAsBytes(), pfad: d.path);
      final zeilen = await textLesen(shot);
      gefunden.addAll(truppenAusText(zeilen, w, bild: shot.bild));
    }
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
  if (!context.mounted) return;
  if (gefunden.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      content: Text(tx(
          'Keine Truppe erkannt. Am besten die Truppen-Ansicht öffnen, sodass Name und Level gut lesbar sind.',
          'No troop found. Open the troop view so that name and level are clearly readable.')),
    ));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TruppenPruefen(db: db, treffer: gefunden),
  );
}

class _TruppenPruefen extends StatefulWidget {
  final Datenbank db;
  final List<TruppenTreffer> treffer;
  const _TruppenPruefen({required this.db, required this.treffer});

  @override
  State<_TruppenPruefen> createState() => _TruppenPruefenState();
}

class _TruppenPruefenState extends State<_TruppenPruefen> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final w = truppenVon(widget.db);
    final liste = widget.treffer;
    final ok = liste.where((x) => x.uebernehmen).every((x) => x.farbe.isNotEmpty);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx('${liste.length} Truppen erkannt', '${liste.length} troops found'), style: t.textTheme.titleLarge),
            Text(tx('Bitte kurz prüfen – Farbe und Level kannst du antippen und ändern.',
                'Please check – tap color and level to change them.'), style: t.textTheme.bodySmall),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final x in liste)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CheckboxListTile(
                      value: x.uebernehmen,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() => x.uebernehmen = v ?? false),
                      title: Text(x.typ == 'leg' ? (x.legName ?? 'Legendär') : truppenTypName(x.typ, w)),
                      subtitle: Text(tx('Gelesen: „${x.gelesen}“', 'Read: "${x.gelesen}"'), style: t.textTheme.bodySmall),
                    ),
                    Wrap(spacing: 4, runSpacing: 4, children: [
                      for (final f in elementFarben.keys)
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          avatar: CircleAvatar(backgroundColor: elementFarben[f], radius: 7),
                          label: Text(elementName(f)),
                          selected: x.farbe == f,
                          onSelected: (_) => setState(() => x.farbe = f),
                        ),
                    ]),
                    if (x.farbe.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(tx('Farbe nicht sicher erkannt – bitte wählen', 'Color not detected – please choose'),
                            style: TextStyle(color: t.colorScheme.error, fontSize: 12)),
                      ),
                    Row(children: [
                      SizedBox(width: 80, child: Text('Level ${x.level}')),
                      Expanded(
                        child: Slider(
                          value: x.level.toDouble(),
                          min: 1,
                          max: x.typ == 'leg' ? 40 : 30,
                          divisions: x.typ == 'leg' ? 39 : 29,
                          label: '${x.level}',
                          onChanged: (v) => setState(() => x.level = v.round()),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: ok ? _speichern : null,
              icon: const Icon(Icons.check),
              label: Text(tx('Übernehmen', 'Import')),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _speichern() async {
    final sammlung = SammlungScope.lesen(context);
    var neu = 0, aktualisiert = 0;
    for (final x in widget.treffer.where((x) => x.uebernehmen && x.farbe.isNotEmpty)) {
      // Gleiche Truppe schon vorhanden? Dann nur das Level aktualisieren.
      final vorhanden = sammlung.truppen
          .where((t) => t.farbe == x.farbe && t.typ == x.typ && t.legName == x.legName)
          .toList();
      if (vorhanden.isNotEmpty) {
        final t = vorhanden.first;
        if (t.level != x.level) {
          t.level = x.level;
          await sammlung.truppeSpeichern(t);
          aktualisiert++;
        }
      } else {
        await sammlung.truppeSpeichern(EigeneTruppe(
          id: '${DateTime.now().microsecondsSinceEpoch}$neu',
          farbe: x.farbe,
          typ: x.typ,
          legName: x.legName,
          sterne: x.typ == 'leg' ? 5 : 4,
          level: x.level,
        ));
        neu++;
      }
    }
    if (!mounted) return;
    final melden = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    melden.showSnackBar(SnackBar(
      content: Text(tx('$neu neue Truppen, $aktualisiert aktualisiert', '$neu new troops, $aktualisiert updated')),
    ));
  }
}
