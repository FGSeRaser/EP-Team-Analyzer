// E&P Team-Analyzer – Gegner-Held einstellen: Kostüm, Stufe, Level, Limit Break, Talent
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../daten/datenbank.dart';
import '../daten/gegner_stand.dart';
import '../daten/sammlung.dart';
import '../daten/sprache.dart';
import '../daten/werte.dart';
import 'held_detail.dart';
import 'widgets.dart';

/// Ergebnis: gewählte Variante (Basis oder Kostüm) + Stand, oder "anderen Helden wählen"
class GegnerAuswahl {
  final Held? held;
  final GegnerStand? stand;
  final bool wechseln;

  /// Eigenes Team: Änderungen auch unter „Meine Helden“ speichern
  final bool speichern;
  const GegnerAuswahl({this.held, this.stand, this.wechseln = false, this.speichern = false});
}

/// [eigen] = eigener Held (Team-Check), sonst Gegner
Future<GegnerAuswahl?> gegnerBearbeiten(BuildContext context, Datenbank db, Held held, GegnerStand stand, {bool eigen = false}) {
  return showModalBottomSheet<GegnerAuswahl>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GegnerSheet(db: db, held: held, start: stand, eigen: eigen),
  );
}

/// Stand eines eigenen Helden aus „Meine Helden“ (Stufe, Level, LB, Talent, Kostüme)
GegnerStand? standAusSammlung(Sammlung sammlung, Datenbank db, Held h) {
  var b = sammlung.besitz(h.id);
  if (b == null) {
    for (final v in db.varianten(h)) {
      b = sammlung.besitz(v.id);
      if (b != null) break;
    }
  }
  if (b == null) return null;
  return GegnerStand(
    stufe: b.stufe,
    level: b.level,
    lb: b.lb,
    talent: b.talent,
    kost: sammlung.kostuemStufen(db, h),
    staerke: b.id == h.id ? b.staerke : null,
  );
}

class _GegnerSheet extends StatefulWidget {
  final Datenbank db;
  final Held held;
  final GegnerStand start;
  final bool eigen;
  const _GegnerSheet({required this.db, required this.held, required this.start, this.eigen = false});

  @override
  State<_GegnerSheet> createState() => _GegnerSheetState();
}

class _GegnerSheetState extends State<_GegnerSheet> {
  late GegnerStand _s;
  late String _aussehen;
  bool _speichern = false;
  final _staerkeFeld = TextEditingController();

  Datenbank get db => widget.db;
  Held get _basis => db.nachId[widget.held.basisId] ?? widget.held;
  Held get _held => db.nachId[_aussehen] ?? widget.held;

  @override
  void initState() {
    super.initState();
    _s = widget.start.kopie();
    _aussehen = widget.held.id;
    // Wer als Kostüm gewählt wurde, hat dieses Kostüm mindestens auf Stufe 1
    if (widget.held.kostuemVon != null && (_s.kost[widget.held.id] ?? 0) == 0) {
      _s.kost[widget.held.id] = db.kostuemStufen(widget.held);
    }
    if (_s.staerke != null) _staerkeFeld.text = '${_s.staerke}';
  }

  @override
  void dispose() {
    _staerkeFeld.dispose();
    super.dispose();
  }

  void _korrigieren() {
    final h = _held;
    final stufen = stufenAnzahl(h.sterne);
    _s.stufe = _s.stufe.clamp(1, stufen);
    if (_s.stufe < stufen) _s.lb = 0;
    _s.level = _s.level.clamp(1, maxLevel(h.sterne, _s.stufe, _s.lb));
  }

  void _ausStaerke() {
    final n = Sammlung().kostuemStufenAusStaerke(
        db, _held, Besitz(id: _held.id, stufe: _s.stufe, level: _s.level, lb: _s.lb, talent: _s.talent, staerke: _s.staerke));
    if (n == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tx('Keine Kostüm-Anzahl passt genau – prüf Level, Limit Break und Talent.',
              'No costume count matches exactly – check level, limit break and talent.'))));
      return;
    }
    final max = db.kostuemStufen(_basis);
    final ids = db.kostuemeVon(_basis).where((k) => !k.kommend).map((k) => k.id).toList()
      ..sort((a, b) => (b == _aussehen ? 1 : 0).compareTo(a == _aussehen ? 1 : 0));
    var rest = n;
    setState(() {
      for (final id in ids) {
        final st = rest >= max ? max : rest;
        _s.kost[id] = st;
        rest -= st;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final h = _held;
    final stufen = stufenAnzahl(h.sterne);
    final maxLb = maxLbAnzahl(h.sterne);
    final maxLv = maxLevel(h.sterne, _s.stufe, _s.lb);
    final w = _s.werte(db, h);
    final kostueme = db.kostuemeVon(_basis).where((k) => !k.kommend).toList();
    final maxKost = db.kostuemStufen(_basis);
    final abweichung = _s.staerke == null ? 0 : _s.staerke! - w.kraft;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            HeldBild(h, groesse: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.eigen ? h.anzeigeName : tx('Gegner: ${h.anzeigeName}', 'Enemy: ${h.anzeigeName}'),
                    style: t.textTheme.titleLarge),
                Sterne(h.sterne),
              ]),
            ),
            IconButton(
              tooltip: 'Details',
              icon: const Icon(Icons.info_outline),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h))),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              widget.eigen
                  ? tx('Stell deinen Helden so ein, wie du ihn hast. Kostüme ändern Werte und teils auch die Fähigkeiten.',
                      'Set your hero up the way you have it. Costumes change stats and sometimes the skills.')
                  : tx('Stell den Helden so ein, wie der Gegner ihn hat. Kostüme ändern Werte und teils auch die Fähigkeiten.',
                      'Set the hero up like the enemy has it. Costumes change stats and sometimes the skills.'),
              style: t.textTheme.bodySmall),

          // ---------- Kostüm ----------
          if (kostueme.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tx('Gespielt als', 'Played as'), style: t.textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final v in [_basis, ...kostueme])
                ChoiceChip(
                  avatar: HeldBild(v, groesse: 22),
                  label: Text(v.kostuemVon == null ? tx('Basis', 'Base') : v.kostuemL),
                  selected: _aussehen == v.id,
                  onSelected: (_) => setState(() {
                    _aussehen = v.id;
                    if (v.kostuemVon != null && (_s.kost[v.id] ?? 0) == 0) _s.kost[v.id] = maxKost;
                  }),
                ),
            ]),
            const SizedBox(height: 10),
            Text(
                widget.eigen
                    ? tx('Kostüm-Stufen (– = nicht im Besitz)', 'Costume levels (– = not owned)')
                    : tx('Kostüm-Stufen des Gegners (– = hat er nicht)', 'Enemy costume levels (– = not owned)'),
                style: t.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final k in kostueme)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  HeldBild(k, groesse: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.kostuemL, style: t.textTheme.bodySmall),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(visualDensity: VisualDensity.compact),
                        segments: [
                          for (var st = 0; st <= maxKost; st++) ButtonSegment(value: st, label: Text(st == 0 ? '–' : '$st')),
                        ],
                        selected: {_s.kost[k.id] ?? 0},
                        onSelectionChanged: (v) => setState(() {
                          _s.kost[k.id] = v.first;
                          if (v.first == 0 && _aussehen == k.id) _aussehen = _basis.id;
                        }),
                      ),
                    ]),
                  ),
                ]),
              ),
          ],

          // ---------- Stufe / LB / Level / Talent ----------
          const SizedBox(height: 10),
          Text(tx('Aufstiegsstufe', 'Ascension')),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            segments: [for (var st = 1; st <= stufen; st++) ButtonSegment(value: st, label: Text('$st'))],
            selected: {_s.stufe.clamp(1, stufen)},
            onSelectionChanged: (v) => setState(() {
              _s.stufe = v.first;
              _s.level = maxLevel(h.sterne, _s.stufe, _s.lb);
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
              selected: {_s.lb},
              onSelectionChanged: _s.stufe < stufen
                  ? null
                  : (v) => setState(() {
                        _s.lb = v.first;
                        _s.level = maxLevel(h.sterne, _s.stufe, _s.lb);
                      }),
            ),
          ],
          const SizedBox(height: 6),
          Row(children: [
            SizedBox(width: 100, child: Text('Level ${_s.level}')),
            Expanded(
              child: Slider(
                value: _s.level.toDouble().clamp(1.0, maxLv.toDouble()),
                min: 1,
                max: maxLv.toDouble(),
                divisions: maxLv > 1 ? maxLv - 1 : null,
                label: '${_s.level}',
                onChanged: maxLv > 1 ? (v) => setState(() => _s.level = v.round()) : null,
              ),
            ),
          ]),
          if (h.sterne >= 3)
            Row(children: [
              SizedBox(width: 100, child: Text('Talent +${_s.talent}')),
              Expanded(
                child: Slider(
                  value: _s.talent.toDouble(),
                  min: 0,
                  max: 25,
                  divisions: 25,
                  label: '+${_s.talent}',
                  onChanged: (v) => setState(() => _s.talent = v.round()),
                ),
              ),
            ]),

          // ---------- Werte ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _wert(tx('Angriff', 'Attack'), w.angriff),
                _wert(tx('Verteid.', 'Defense'), w.verteidigung),
                _wert(tx('Leben', 'Health'), w.leben),
                _wert(tx('Stärke', 'Power'), w.kraft),
              ]),
            ),
          ),
          const SizedBox(height: 8),
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
                onChanged: (v) => setState(() => _s.staerke = int.tryParse(v)),
              ),
            ),
            if (kostueme.isNotEmpty && _s.staerke != null && abweichung != 0) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _ausStaerke,
                child: Text(tx('Kostüme\nberechnen', 'Detect\ncostumes'), textAlign: TextAlign.center),
              ),
            ],
          ]),
          if (_s.staerke != null && abweichung != 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                tx('Spiel: ${_s.staerke} · berechnet: ${w.kraft} – es zählt die Spiel-Stärke.',
                    'Game: ${_s.staerke} · calculated: ${w.kraft} – the game power is used.'),
                style: t.textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
            ),
          if (widget.eigen)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(tx('Auch unter „Meine Helden“ speichern', 'Also save under "My heroes"')),
              value: _speichern,
              onChanged: (v) => setState(() => _speichern = v),
            ),
          const SizedBox(height: 12),
          Row(children: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, const GegnerAuswahl(wechseln: true)),
              icon: const Icon(Icons.swap_horiz),
              label: Text(tx('Anderer Held', 'Other hero')),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => setState(() {
                _s.stufe = stufen;
                _s.lb = maxLb;
                _s.level = maxLevel(h.sterne, stufen, maxLb);
              }),
              child: Text(tx('Max', 'Max')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                _korrigieren();
                Navigator.pop(context, GegnerAuswahl(held: _held, stand: _s, speichern: _speichern));
              },
              child: Text(tx('Übernehmen', 'Apply')),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _wert(String name, int v) => Column(children: [
        Text('$v', style: Theme.of(context).textTheme.titleMedium),
        Text(name, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
