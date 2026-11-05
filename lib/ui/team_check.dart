// E&P Team-Analyzer – Team-Check: 5 Helden wählen, Stärken und Lücken sehen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/analyse.dart';
import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import 'held_detail.dart';
import 'helden_liste.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

class TeamCheck extends StatefulWidget {
  final Datenbank db;

  /// Optional: Team, mit dem die Seite startet (z. B. aus dem Team-Builder)
  final List<Held> start;
  const TeamCheck({super.key, required this.db, this.start = const []});

  @override
  State<TeamCheck> createState() => _TeamCheckState();
}

class _TeamCheckState extends State<TeamCheck> {
  final List<Held?> _slots = List<Held?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.start.length && i < 5; i++) {
      _slots[i] = widget.start[i];
    }
  }

  static List<String> get _positionen => [
        tx('Flanke L', 'Flank L'),
        tx('Flügel L', 'Wing L'),
        'Tank',
        tx('Flügel R', 'Wing R'),
        tx('Flanke R', 'Flank R'),
      ];

  Future<void> _waehle(int i) async {
    final hatSammlung = SammlungScope.lesen(context).anzahlVerschiedene > 0;
    final h = await Navigator.push<Held>(
      context,
      MaterialPageRoute(
        builder: (_) => HeldenListe(db: widget.db, auswahl: true, nurMeineStart: hatSammlung),
      ),
    );
    if (h != null) setState(() => _slots[i] = h);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final team = _slots.whereType<Held>().toList();
    final bericht = Analyse(widget.db).team(team);
    final db = widget.db;

    return Scaffold(
      appBar: AppBar(
        title: Text(tx('Team-Check', 'Team check')),
        actions: [
          if (team.isNotEmpty)
            IconButton(
              tooltip: tx('Leeren', 'Clear'),
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => setState(() => _slots.fillRange(0, 5, null)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _waehle(i),
                      onLongPress: _slots[i] == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: _slots[i]!)),
                              ),
                      child: Column(children: [
                        _slots[i] == null
                            ? Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: t.colorScheme.outline),
                                ),
                                child: const Icon(Icons.add),
                              )
                            : HeldBild(_slots[i]!, groesse: 58),
                        const SizedBox(height: 4),
                        Text(
                          _slots[i]?.nameL ?? _positionen[i],
                          style: t.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_slots[i] != null)
                          InkWell(
                            onTap: () => setState(() => _slots[i] = null),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, size: 16),
                            ),
                          ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(tx('Tippen = Held wählen · Gedrückt halten = Details', 'Tap = pick hero · Long press = details'),
                style: t.textTheme.bodySmall, textAlign: TextAlign.center),
          ),
          if (team.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                tx('Wähle bis zu 5 Helden. Die App zeigt dir, gegen welche gegnerischen Effekte dein Team gewappnet ist und wo Lücken sind.',
                    'Pick up to 5 heroes. The app shows which enemy effects your team is prepared for and where the gaps are.'),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Abschnitt(tx('Überblick', 'Overview'), icon: Icons.insights, kinder: [
              Text(tx('Kraft gesamt: ${bericht.kraft}', 'Total power: ${bericht.kraft}')),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final e in bericht.farben.entries)
                  Chip(
                    avatar: CircleAvatar(backgroundColor: elementFarbe(e.key), radius: 7),
                    label: Text('${elementName(e.key)}: ${e.value}'),
                    visualDensity: VisualDensity.compact,
                  ),
                for (final e in bericht.tempo.entries)
                  Chip(label: Text('${e.key}: ${e.value}'), visualDensity: VisualDensity.compact),
              ]),
            ]),
            Abschnitt(tx('Grundbausteine', 'Essentials'), icon: Icons.checklist, kinder: [
              for (final b in bericht.bausteine.entries)
                Row(children: [
                  Icon(b.value ? Icons.check_circle : Icons.cancel,
                      color: b.value ? Colors.green : Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(bausteinName(b.key)),
                ]),
            ]),
            if (bericht.hinweise.isNotEmpty)
              Abschnitt(tx('Hinweise', 'Hints'), icon: Icons.lightbulb, kinder: [
                for (final h in bericht.hinweise)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $h'),
                  ),
              ]),
            Abschnitt(tx('Gewappnet gegen', 'Prepared for'), icon: Icons.verified_user, kinder: [
              if (bericht.abgedeckt.isEmpty) Text(tx('Noch nichts abgedeckt.', 'Nothing covered yet.')),
              for (final e in bericht.abgedeckt.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${db.bedrohungName(e.key)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: e.value.map((h) => h.nameL).join(', ')),
                  ])),
                ),
            ]),
            if (bericht.teilweise.isNotEmpty)
              Abschnitt(tx('Nur abgefedert', 'Only softened'), icon: Icons.shield_outlined, kinder: [
                for (final e in bericht.teilweise.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${db.bedrohungName(e.key)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: e.value.map((h) => h.nameL).join(', ')),
                    ])),
                  ),
                Text(tx('Kein echter Konter – der Schaden wird nur gemildert.', 'No real counter – damage is only reduced.'), style: t.textTheme.bodySmall),
              ]),
            if (bericht.luecken.isNotEmpty)
              Abschnitt(tx('Schwach gegen', 'Weak against'), icon: Icons.warning_amber, kinder: [
                for (final k in bericht.luecken)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(db.bedrohungName(k), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(db.bedrohungTipp(k), style: t.textTheme.bodySmall),
                      if ((db.bedrohungen[k]?.counters ?? const []).isNotEmpty)
                        Text('${tx('Hilft', 'Helps')}: ${db.bedrohungen[k]!.counters.take(4).map(db.effektName).join(', ')}',
                            style: t.textTheme.bodySmall?.copyWith(color: Colors.green)),
                    ]),
                  ),
              ]),
            if (bericht.immun.isNotEmpty)
              Abschnitt(tx('Immunitäten im Team', 'Immunities in the team'), icon: Icons.health_and_safety, kinder: [
                for (final e in bericht.immun.entries)
                  Text('${db.bedrohungName(e.key)}: ${e.value.map((h) => h.nameL).join(', ')}'),
              ]),
          ],
        ],
      ),
    );
  }
}
