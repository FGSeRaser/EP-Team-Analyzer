// E&P Team-Analyzer – Team-Builder: beste Teams aus der eigenen Sammlung
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'dart:math' as math;

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

  /// Welche Sterne der Builder benutzen darf
  final Set<int> _sterne = {3, 4, 5};

  /// Bisher gezeigte Teams – „Neu würfeln“ sucht andere Kombinationen
  final List<Set<String>> _gezeigt = [];
  int _wurf = 0;

  List<Held> _gefiltert(List<Held> pool) => pool.where((h) => _sterne.contains(h.sterne <= 3 ? 3 : h.sterne)).toList();

  void _zuruecksetzen() {
    _ergebnis = null;
    _gezeigt.clear();
    _wurf = 0;
  }

  Future<void> _bauen({bool wuerfeln = false}) async {
    final p = eigenerPool(context, widget.db);
    final pool = _gefiltert(p.pool);
    if (pool.length < 5) return;
    if (!wuerfeln) _gezeigt.clear();
    setState(() {
      _laeuft = true;
      _ergebnis = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50)); // Ladeanzeige zeigen
    final b = TeamBuilder(
      Analyse(widget.db),
      kraftVon: p.kraft,
      truppenInventar: p.truppen,
      zufall: wuerfeln ? math.Random() : null,
      schonGezeigt: wuerfeln ? List.of(_gezeigt) : const [],
    );
    var erg = _modus == Modus.krieg
        ? b.krieg(pool)
        : b.baue(pool, _modus, titanFarbe: _modus == Modus.titan ? _titanFarbe : null);
    // Alles schon gesehen? Dann wieder von vorn mischen.
    if (erg.isEmpty && wuerfeln) {
      _gezeigt.clear();
      final b2 = TeamBuilder(Analyse(widget.db), kraftVon: p.kraft, truppenInventar: p.truppen, zufall: math.Random());
      erg = _modus == Modus.krieg ? b2.krieg(pool) : b2.baue(pool, _modus, titanFarbe: _modus == Modus.titan ? _titanFarbe : null);
    }
    if (!mounted) return;
    setState(() {
      _ergebnis = erg;
      _laeuft = false;
      _wurf = wuerfeln ? _wurf + 1 : 0;
      for (final v in erg) {
        _gezeigt.add(v.helden.map((h) => h.basisId).toSet());
      }
      while (_gezeigt.length > 15) {
        _gezeigt.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final gesamt = SammlungScope.of(context).anzahlVerschiedene;
    final anzahl = _gefiltert(eigenerPool(context, widget.db).pool).map((h) => h.basisId).toSet().length;
    final erg = _ergebnis;
    return Scaffold(
      appBar: AppBar(title: Text(tx('Team-Builder', 'Team builder'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              tx('Die App sucht aus deinen $anzahl passenden Helden (von $gesamt) Teams, die zusammen funktionieren und sich gegenseitig unterstützen.',
                  'The app builds teams from your $anzahl matching heroes (of $gesamt) that work together and support each other.'),
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
                    _zuruecksetzen();
                  }),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tx('Erlaubte Helden', 'Allowed heroes'), style: t.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final st in const [5, 4, 3])
                  FilterChip(
                    label: Text(st == 3 ? '1–3★' : '$st★'),
                    selected: _sterne.contains(st),
                    onSelected: (an) => setState(() {
                      if (an) {
                        _sterne.add(st);
                      } else if (_sterne.length > 1) {
                        _sterne.remove(st);
                      }
                      _zuruecksetzen();
                    }),
                  ),
              ]),
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
                        _zuruecksetzen();
                      }),
                    ),
                ]),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: anzahl < 5 || _laeuft ? null : () => _bauen(),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(tx('Teams bauen', 'Build teams')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: anzahl < 5 || _laeuft ? null : () => _bauen(wuerfeln: true),
                  icon: const Icon(Icons.casino),
                  label: Text(tx('Neu würfeln', 'Reroll')),
                ),
              ),
            ]),
          ),
          if (_wurf > 0 && !_laeuft)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                tx('Wurf $_wurf – neue Kombinationen, die sich von den bisherigen unterscheiden.',
                    'Roll $_wurf – new combinations that differ from the previous ones.'),
                style: t.textTheme.bodySmall,
              ),
            ),
          if (anzahl < 5)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                gesamt < 5
                    ? tx('Trag zuerst mindestens 5 Helden unter „Meine“ ein.', 'First add at least 5 heroes under "Mine".')
                    : tx('Mit dieser Sterne-Auswahl hast du weniger als 5 Helden – wähl mehr Sterne aus.',
                        'Fewer than 5 heroes with this star filter – select more stars.'),
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
                tx('Bewertet werden Aufgaben im Team (Tank, Heilung, Reinigen, Bannen …), wie sich die Helden gegenseitig '
                        'unterstützen (Verstärker + Schadensmacher, Mana-Helfer + langsame Helden, Farb-Stapel), '
                        'ausgewogene Rollen, Stärke, Mana-Tempo und beim Titan der Farbvorteil. '
                        'Gefällt dir ein Team nicht: „Neu würfeln“.',
                    'Rated: team tasks (tank, healing, cleanse, dispel …), how heroes support each other '
                        '(boosters + damage dealers, mana helpers + slow heroes, color stacks), balanced roles, '
                        'power, mana speed and, for titans, the color advantage. Don\'t like a team? "Reroll".'),
                style: t.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
