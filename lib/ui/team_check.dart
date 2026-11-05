// E&P Team-Analyzer – Team-Check: 5 Helden wählen, Stärken und Lücken sehen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/analyse.dart';
import '../daten/datenbank.dart';
import 'held_detail.dart';
import 'helden_liste.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

class TeamCheck extends StatefulWidget {
  final Datenbank db;
  const TeamCheck({super.key, required this.db});

  @override
  State<TeamCheck> createState() => _TeamCheckState();
}

class _TeamCheckState extends State<TeamCheck> {
  final List<Held?> _slots = List<Held?>.filled(5, null);

  static const _positionen = ['Flanke L', 'Flügel L', 'Tank', 'Flügel R', 'Flanke R'];

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
        title: const Text('Team-Check'),
        actions: [
          if (team.isNotEmpty)
            IconButton(
              tooltip: 'Leeren',
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
                          _slots[i]?.name ?? _positionen[i],
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
            child: Text('Tippen = Held wählen · Gedrückt halten = Details',
                style: t.textTheme.bodySmall, textAlign: TextAlign.center),
          ),
          if (team.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Wähle bis zu 5 Helden. Die App zeigt dir, gegen welche gegnerischen Effekte dein Team '
                'gewappnet ist und wo Lücken sind.',
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Abschnitt('Überblick', icon: Icons.insights, kinder: [
              Text('Kraft gesamt: ${bericht.kraft}'),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final e in bericht.farben.entries)
                  Chip(
                    avatar: CircleAvatar(backgroundColor: elementFarbe(e.key), radius: 7),
                    label: Text('${elementNamen[e.key] ?? e.key}: ${e.value}'),
                    visualDensity: VisualDensity.compact,
                  ),
                for (final e in bericht.tempo.entries)
                  Chip(label: Text('${e.key}: ${e.value}'), visualDensity: VisualDensity.compact),
              ]),
            ]),
            Abschnitt('Grundbausteine', icon: Icons.checklist, kinder: [
              for (final b in bericht.bausteine.entries)
                Row(children: [
                  Icon(b.value ? Icons.check_circle : Icons.cancel,
                      color: b.value ? Colors.green : Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(b.key),
                ]),
            ]),
            if (bericht.hinweise.isNotEmpty)
              Abschnitt('Hinweise', icon: Icons.lightbulb, kinder: [
                for (final h in bericht.hinweise)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $h'),
                  ),
              ]),
            Abschnitt('Gewappnet gegen', icon: Icons.verified_user, kinder: [
              if (bericht.abgedeckt.isEmpty) const Text('Noch nichts abgedeckt.'),
              for (final e in bericht.abgedeckt.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${db.bedrohungName(e.key)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: e.value.map((h) => h.name).join(', ')),
                  ])),
                ),
            ]),
            if (bericht.teilweise.isNotEmpty)
              Abschnitt('Nur abgefedert', icon: Icons.shield_outlined, kinder: [
                for (final e in bericht.teilweise.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${db.bedrohungName(e.key)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: e.value.map((h) => h.name).join(', ')),
                    ])),
                  ),
                Text('Kein echter Konter – der Schaden wird nur gemildert.', style: t.textTheme.bodySmall),
              ]),
            if (bericht.luecken.isNotEmpty)
              Abschnitt('Schwach gegen', icon: Icons.warning_amber, kinder: [
                for (final k in bericht.luecken)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(db.bedrohungName(k), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(db.bedrohungen[k]?.tipp ?? '', style: t.textTheme.bodySmall),
                      if ((db.bedrohungen[k]?.counters ?? const []).isNotEmpty)
                        Text('Hilft: ${db.bedrohungen[k]!.counters.take(4).map(db.effektName).join(', ')}',
                            style: t.textTheme.bodySmall?.copyWith(color: Colors.green)),
                    ]),
                  ),
              ]),
            if (bericht.immun.isNotEmpty)
              Abschnitt('Immunitäten im Team', icon: Icons.health_and_safety, kinder: [
                for (final e in bericht.immun.entries)
                  Text('${db.bedrohungName(e.key)}: ${e.value.map((h) => h.name).join(', ')}'),
              ]),
          ],
        ],
      ),
    );
  }
}
