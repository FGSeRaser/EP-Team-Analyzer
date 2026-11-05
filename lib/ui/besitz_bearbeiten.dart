// E&P Team-Analyzer – eigenen Helden bearbeiten: Stufe, Level, Limit Break, Talent, Kostüme
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../daten/datenbank.dart';
import '../daten/sammlung.dart';
import '../daten/sprache.dart';
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
  late String _aussehen; // welche Variante (Basis oder Kostüm) gespielt wird
  late Map<String, int> _kost; // Kostüm-ID -> Stufe (0 = nicht im Besitz)
  final _staerkeFeld = TextEditingController();

  Datenbank get db => widget.db;

  @override
  void initState() {
    super.initState();
    final sammlung = SammlungScope.lesen(context);
    final vorhanden = sammlung.besitz(widget.held.id);
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
    _aussehen = widget.held.id;
    _kost = sammlung.kostuemStufen(db, widget.held);
    // Wer als Kostüm hinzugefügt wird, besitzt dieses Kostüm
    if (widget.held.kostuemVon != null && (_kost[widget.held.id] ?? 0) == 0) {
      _kost[widget.held.id] = db.kostuemStufen(widget.held);
    }
    if (_b.staerke != null) _staerkeFeld.text = '${_b.staerke}';
  }

  @override
  void dispose() {
    _staerkeFeld.dispose();
    super.dispose();
  }

  Held get _held => db.nachId[_aussehen] ?? widget.held;
  int get _kostGesamt => _kost.values.fold(0, (a, b) => a + b);
  List<int>? get _bonus => kostuemBonusFuer(db.kostuemTabelle(widget.held), _kostGesamt);

  void _korrigieren() {
    final h = widget.held;
    final stufen = stufenAnzahl(h.sterne);
    _b.stufe = _b.stufe.clamp(1, stufen);
    if (_b.stufe < stufen) _b.lb = 0;
    _b.level = _b.level.clamp(1, maxLevel(h.sterne, _b.stufe, _b.lb));
  }

  /// Kostüm-Stufen aus der Spiel-Stärke ableiten und der Reihe nach auf die Kostüme verteilen
  void _ausStaerke() {
    final probe = Besitz(id: _b.id, stufe: _b.stufe, level: _b.level, lb: _b.lb, talent: _b.talent, staerke: _b.staerke);
    final n = SammlungScope.lesen(context).kostuemStufenAusStaerke(db, _held, probe);
    if (n == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tx('Keine Kostüm-Anzahl passt genau – prüf Level, Limit Break und Talent.',
              'No costume count matches exactly – check level, limit break and talent.'))));
      return;
    }
    final max = db.kostuemStufen(widget.held);
    final ids = _kost.keys.toList();
    // gespielte Variante zuerst, dann der Rest
    ids.sort((a, b) => (b == _aussehen ? 1 : 0).compareTo(a == _aussehen ? 1 : 0));
    var rest = n;
    setState(() {
      for (final id in ids) {
        final s = rest >= max ? max : rest;
        _kost[id] = s;
        rest -= s;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final h = _held;
    final stufen = stufenAnzahl(h.sterne);
    final maxLb = maxLbAnzahl(h.sterne);
    final maxLv = maxLevel(h.sterne, _b.stufe, _b.lb);
    final w = berechne(h.sterne, h.basis, _b.stufe, _b.level, _b.lb, talent: _b.talent, kostuemBonus: _bonus);
    final sammlung = SammlungScope.lesen(context);
    final kostueme = db.kostuemeVon(widget.held).where((k) => !k.kommend).toList();
    final maxKost = db.kostuemStufen(widget.held);
    final varianten = [
      db.nachId[widget.held.basisId] ?? widget.held,
      ...kostueme.where((k) => (_kost[k.id] ?? 0) > 0),
    ];
    final bonus = _bonus;
    final abweichung = _b.staerke == null ? 0 : _b.staerke! - w.kraft;

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
                  MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h)),
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
                  for (var l = 0; l <= maxLb; l++)
                    ButtonSegment(value: l, label: Text(l == 0 ? tx('Keiner', 'None') : 'LB$l')),
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

            // ---------- Kostüme ----------
            if (kostueme.isNotEmpty) ...[
              const Divider(height: 24),
              Row(children: [
                Expanded(child: Text(tx('Kostüme', 'Costumes'), style: t.textTheme.titleMedium)),
                TextButton(
                  onPressed: () => setState(() {
                    for (final k in kostueme) {
                      _kost[k.id] = maxKost;
                    }
                  }),
                  child: Text(tx('Alle max', 'All max')),
                ),
              ]),
              Text(
                tx('Stufe je Kostüm (– = nicht im Besitz). Der Bonus gilt für den Helden und alle seine Kostüme.',
                    'Level per costume (– = not owned). The bonus applies to the hero and all its costumes.'),
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final k in kostueme)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    HeldBild(k, groesse: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(k.kostuemL, style: t.textTheme.titleSmall),
                        const SizedBox(height: 4),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: [
                            for (var s = 0; s <= maxKost; s++) ButtonSegment(value: s, label: Text(s == 0 ? '–' : '$s')),
                          ],
                          selected: {_kost[k.id] ?? 0},
                          onSelectionChanged: (v) => setState(() {
                            _kost[k.id] = v.first;
                            if (v.first == 0 && _aussehen == k.id) _aussehen = widget.held.basisId;
                          }),
                        ),
                      ]),
                    ),
                  ]),
                ),
              Text(
                bonus == null
                    ? tx('Kein Kostümbonus', 'No costume bonus')
                    : tx(
                        'Kostümbonus: Angriff +${bonus[0] / 10} %, Verteidigung +${bonus[1] / 10} %, Leben +${bonus[2] / 10} %, Mana +${bonus[3] / 10} %',
                        'Costume bonus: attack +${bonus[0] / 10}%, defense +${bonus[1] / 10}%, health +${bonus[2] / 10}%, mana +${bonus[3] / 10}%'),
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.primary),
              ),
              if (varianten.length > 1) ...[
                const SizedBox(height: 10),
                Text(tx('Gespielt als', 'Played as')),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final v in varianten)
                    ChoiceChip(
                      avatar: HeldBild(v, groesse: 22),
                      label: Text(v.kostuemTyp == null ? tx('Basis', 'Base') : v.kostuemL),
                      selected: _aussehen == v.id,
                      onSelected: (_) => setState(() => _aussehen = v.id),
                    ),
                ]),
              ],
            ],

            // ---------- Werte ----------
            const Divider(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _wert(tx('Angriff', 'Attack'), w.angriff),
                    _wert(tx('Verteid.', 'Defense'), w.verteidigung),
                    _wert(tx('Leben', 'Health'), w.leben),
                    _wert(tx('Stärke', 'Power'), w.kraft),
                  ],
                ),
              ),
            ),
            Text(
              tx('Berechnet wie im Spiel (Level, Limit Break, Kostüme, Talentpunkte × 5). Embleme ändern die Stärke nicht.',
                  'Calculated like the game (level, limit break, costumes, talent points × 5). Emblems don\'t change power.'),
              style: t.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _staerkeFeld,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: tx('Stärke laut Spiel (optional)', 'In-game power (optional)'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _b.staerke = int.tryParse(v)),
                ),
              ),
              if (kostueme.isNotEmpty && _b.staerke != null && abweichung != 0) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _ausStaerke,
                  child: Text(tx('Kostüme\nberechnen', 'Detect\ncostumes'), textAlign: TextAlign.center),
                ),
              ],
            ]),
            if (_b.staerke != null && abweichung != 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tx('Spiel: ${_b.staerke} · berechnet: ${w.kraft} (${abweichung > 0 ? '+' : ''}$abweichung)',
                      'Game: ${_b.staerke} · calculated: ${w.kraft} (${abweichung > 0 ? '+' : ''}$abweichung)'),
                  style: t.textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
              ),
            if (_b.staerke != null && abweichung == 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tx('✓ Passt genau zur Stärke im Spiel', '✓ Matches the in-game power exactly'),
                    style: t.textTheme.bodySmall?.copyWith(color: Colors.green)),
              ),
            const SizedBox(height: 12),
            Row(children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _b.stufe = stufen;
                  _b.lb = maxLb;
                  _b.level = maxLevel(h.sterne, stufen, maxLb);
                }),
                child: Text(tx('Auf Max', 'Set max')),
              ),
              const Spacer(),
              if (!_neu)
                TextButton(
                  onPressed: () async {
                    await sammlung.entfernen(widget.held.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(tx('Entfernen', 'Remove'), style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  _korrigieren();
                  await sammlung.kostuemeSetzen(widget.held.basisId, _kost);
                  if (_aussehen != widget.held.id) {
                    // Variante gewechselt: Eintrag unter der neuen ID speichern
                    if (!_neu) await sammlung.entfernen(widget.held.id);
                    await sammlung.aktualisieren(Besitz(
                      id: _aussehen,
                      anzahl: _b.anzahl,
                      stufe: _b.stufe,
                      level: _b.level,
                      lb: _b.lb,
                      talent: _b.talent,
                      staerke: _b.staerke,
                      notiz: _b.notiz,
                    ));
                  } else {
                    await sammlung.aktualisieren(_b);
                  }
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
