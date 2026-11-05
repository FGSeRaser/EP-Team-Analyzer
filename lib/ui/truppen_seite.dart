// E&P Team-Analyzer – Truppen-Übersicht
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/truppen.dart';
import 'widgets.dart';

class TruppenSeite extends StatefulWidget {
  final Datenbank db;
  const TruppenSeite({super.key, required this.db});

  @override
  State<TruppenSeite> createState() => _TruppenSeiteState();
}

class _TruppenSeiteState extends State<TruppenSeite> {
  String? _klasse;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final w = truppenVon(widget.db);
    final legendaer = w.legendaer
        .where((l) => _klasse == null || l.klasse1 == _klasse || l.klasse2 == _klasse)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(tx('Truppen', 'Troops'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Abschnitt(tx('Grundregeln', 'Basics'), icon: Icons.menu_book, kinder: [
            Text(tx(
              '• Ein Held benutzt immer eine Truppe seiner eigenen Farbe.\n'
                  '• Angriff, Raids, Krieg: Mana-Truppen (Magie > Styx > Mana) – die Spezialfähigkeit kommt schneller.\n'
                  '• Verteidigung und Titan: Krit-Truppen – mehr Verteidigung und doppelter Steinschaden.\n'
                  '• Legendäre Truppen: volle Boni und Passiv nur, wenn die Klasse des Helden passt.\n'
                  '• Mana-Bonus zählt zusammen: Truppe + Kostüm (+5 %) + Embleme (+2/4 %).',
              '• A hero always uses a troop of its own color.\n'
                  '• Attack, raids, war: mana troops (magic > styx > mana) – the special charges faster.\n'
                  '• Defense and titans: crit troops – more defense and double tile damage.\n'
                  '• Legendary troops: full bonuses and passive only if the hero class matches.\n'
                  '• Mana bonuses add up: troop + costume (+5%) + emblems (+2/4%).',
            )),
          ]),
          Abschnitt(tx('Epische Truppen (4★)', 'Epic troops (4★)'), icon: Icons.shield, kinder: [
            for (final e in w.episch)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.label, style: t.textTheme.titleSmall),
                  Text(e.text),
                  if (e.mana.isNotEmpty)
                    Text('${tx('Mana', 'Mana')}: ${e.mana.map((s) => 'Lv${s[0]} +${s[1]}%').join(' · ')}',
                        style: t.textTheme.bodySmall),
                  if (e.krit.isNotEmpty)
                    Text('${tx('Krit', 'Crit')}: ${e.krit.map((s) => 'Lv${s[0]} ${s[1]}%').join(' · ')}',
                        style: t.textTheme.bodySmall),
                  if (e.umgehen.isNotEmpty)
                    Text('${tx('Umgehen', 'Bypass')}: ${e.umgehen.map((s) => 'Lv${s[0]} ${s[1]}%').join(' · ')}',
                        style: t.textTheme.bodySmall),
                  if (e.namen.isNotEmpty)
                    Text(e.namen.entries.map((n) => '${elementName(n.key)}: ${n.value}').join(' · '),
                        style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                ]),
              ),
          ]),
          Abschnitt(tx('Legendäre Truppen (5★)', 'Legendary troops (5★)'), icon: Icons.workspace_premium, kinder: [
            Text(tx('Gibt es in allen 5 Farben. Filter nach Heldenklasse:', 'Available in all 5 colors. Filter by hero class:')),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              ChoiceChip(
                label: Text(tx('Alle', 'All')),
                selected: _klasse == null,
                onSelected: (_) => setState(() => _klasse = null),
              ),
              for (final k in w.klassen.keys)
                ChoiceChip(
                  label: Text(w.klasseName(k)),
                  selected: _klasse == k,
                  onSelected: (_) => setState(() => _klasse = k),
                ),
            ]),
            const SizedBox(height: 8),
            for (final l in legendaer)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.military_tech),
                title: Text(l.name),
                subtitle: Text(
                  '${tx('Haupt', 'Primary')}: ${w.klasseName(l.klasse1)} · ${tx('Neben', 'Secondary')}: ${w.klasseName(l.klasse2)}\n'
                  '${w.passive[l.passiv]?.label ?? l.passiv}',
                ),
                isThreeLine: true,
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              tx('Genaue Prozentwerte der legendären Truppen stehen im Spiel unter Kaserne.',
                  'Exact percentages of legendary troops are shown in the game under Barracks.'),
              style: t.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
