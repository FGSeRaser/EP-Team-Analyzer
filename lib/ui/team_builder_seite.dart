// E&P Team-Analyzer – Team-Builder: beste Teams aus der eigenen Sammlung
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/analyse.dart';
import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/team_builder.dart';
import '../daten/truppen_besitz.dart';
import 'sammlung_scope.dart';
import 'team_karte.dart';
import 'widgets.dart';

/// Eigene Helden + ihre Stärke (Spiel-Stärke, sonst berechnet)
({List<Held> pool, Map<String, int> kraft, List<EigeneTruppe> truppen}) eigenerPool(BuildContext context, Datenbank db) {
  final sammlung = SammlungScope.lesen(context);
  final pool = <Held>[];
  final kraft = <String, int>{};
  for (final e in sammlung.mitHelden(db)) {
    if (e.key.kommend) continue;
    pool.add(e.key);
    kraft[e.key.id] = sammlung.staerke(db, e.key, e.value);
  }
  return (pool: pool, kraft: kraft, truppen: sammlung.truppen);
}

class TeamBuilderSeite extends StatefulWidget {
  final Datenbank db;
  const TeamBuilderSeite({super.key, required this.db});

  @override
  State<TeamBuilderSeite> createState() => _TeamBuilderSeiteState();
}

class _TeamBuilderSeiteState extends State<TeamBuilderSeite> {
  Modus _modus = Modus.verteidigung;
  String _titanFarbe = 'rot';
  bool _laeuft = false;
  List<TeamVorschlag>? _ergebnis;

  Future<void> _bauen() async {
    final p = eigenerPool(context, widget.db);
    if (p.pool.length < 5) return;
    setState(() {
      _laeuft = true;
      _ergebnis = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50)); // Ladeanzeige zeigen
    final b = TeamBuilder(Analyse(widget.db), kraftVon: p.kraft, truppenInventar: p.truppen);
    final erg = _modus == Modus.krieg
        ? b.krieg(p.pool)
        : b.baue(p.pool, _modus, titanFarbe: _modus == Modus.titan ? _titanFarbe : null);
    if (!mounted) return;
    setState(() {
      _ergebnis = erg;
      _laeuft = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final anzahl = SammlungScope.of(context).anzahlVerschiedene;
    final erg = _ergebnis;
    return Scaffold(
      appBar: AppBar(title: Text(tx('Team-Builder', 'Team builder'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              tx('Die App sucht aus deinen $anzahl Helden die besten 5er-Teams für den gewählten Modus.',
                  'The app picks the best teams of 5 from your $anzahl heroes for the chosen mode.'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              for (final m in [Modus.verteidigung, Modus.angriff, Modus.krieg, Modus.titan])
                ChoiceChip(
                  label: Text(modusName(m)),
                  selected: _modus == m,
                  onSelected: (_) => setState(() {
                    _modus = m;
                    _ergebnis = null;
                  }),
                ),
            ]),
          ),
          if (_modus == Modus.titan)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tx('Farbe des Titanen', 'Titan color'), style: t.textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  for (final f in elementFarben.keys)
                    ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: elementFarben[f], radius: 7),
                      label: Text(elementName(f)),
                      selected: _titanFarbe == f,
                      onSelected: (_) => setState(() {
                        _titanFarbe = f;
                        _ergebnis = null;
                      }),
                    ),
                ]),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: anzahl < 5 || _laeuft ? null : _bauen,
              icon: const Icon(Icons.auto_awesome),
              label: Text(tx('Teams bauen', 'Build teams')),
            ),
          ),
          if (anzahl < 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                tx('Trag zuerst mindestens 5 Helden unter „Meine“ ein.', 'First add at least 5 heroes under "Mine".'),
                style: TextStyle(color: t.colorScheme.error),
              ),
            ),
          if (_laeuft) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (erg != null && erg.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tx('Keine Teams gefunden.', 'No teams found.')),
            ),
          if (erg != null)
            for (var i = 0; i < erg.length; i++)
              TeamKarte(
                db: widget.db,
                v: erg[i],
                titel: _modus == Modus.krieg
                    ? tx('Kriegsteam ${i + 1}', 'War team ${i + 1}')
                    : (i == 0 ? tx('Bestes Team', 'Best team') : tx('Alternative $i', 'Alternative $i')),
                positionen: _modus == Modus.verteidigung,
              ),
          if (erg != null && erg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tx('Bewertet werden Stärke, Grundbausteine (Heilung, Reinigen, Bannen …), Mana-Tempo, '
                        'Familienboni und beim Titan der Farbvorteil.',
                    'Rated: power, essentials (healing, cleanse, dispel …), mana speed, family bonuses '
                        'and, for titans, the color advantage.'),
                style: t.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
