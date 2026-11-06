// E&P Team-Analyzer – Hero-Analyser: beste Talente (Embleme) je Held, Position und Einsatz
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/gegner_stand.dart';
import '../daten/sprache.dart';
import '../daten/talente.dart';
import 'gegner_held_sheet.dart';
import 'helden_liste.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

class HeldAnalyseSeite extends StatefulWidget {
  final Datenbank db;
  final Held? start;
  const HeldAnalyseSeite({super.key, required this.db, this.start});

  @override
  State<HeldAnalyseSeite> createState() => _HeldAnalyseSeiteState();
}

class _HeldAnalyseSeiteState extends State<HeldAnalyseSeite> {
  Held? _held;
  GegnerStand? _stand;
  Einsatz _einsatz = Einsatz.verteidigung;
  String _position = 'flanke';
  bool _meister = true;
  late final Future<Map<String, TalentRaster>> _raster = TalentRaster.laden();

  Datenbank get db => widget.db;

  @override
  void initState() {
    super.initState();
    if (widget.start != null) _setzen(widget.start!);
  }

  void _setzen(Held h) {
    _held = h;
    _stand = standAusSammlung(SammlungScope.lesen(context), db, h) ?? GegnerStand.standard(h);
    // Sinnvolle Startposition vorschlagen
    _position = TalentAnalyse.positionsTipps(h, _stand!.werte(db, h)).first.position;
  }

  Future<void> _waehle() async {
    final hatSammlung = SammlungScope.lesen(context).anzahlVerschiedene > 0;
    final h = await Navigator.push<Held>(
      context,
      MaterialPageRoute(builder: (_) => HeldenListe(db: db, auswahl: true, nurMeineStart: hatSammlung)),
    );
    if (h != null && mounted) setState(() => _setzen(h));
  }

  Future<void> _bearbeiten() async {
    final h = _held;
    if (h == null) return;
    final erg = await gegnerBearbeiten(context, db, h, _stand ?? GegnerStand.standard(h), eigen: true);
    if (erg == null || !mounted) return;
    if (erg.wechseln) {
      await _waehle();
      return;
    }
    setState(() {
      if (erg.held != null) _held = erg.held;
      if (erg.stand != null) _stand = erg.stand;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final h = _held;
    return Scaffold(
      appBar: AppBar(title: const Text('Hero-Analyser')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              tx('Wähl einen Helden, seinen Ausbau, wofür du ihn nutzt und wo er steht. Die App sagt dir für jede Gabelung im Talent-Raster, welche Seite du nehmen solltest – und ob eine andere Position besser passt.',
                  'Pick a hero, its build, what you use it for and where it stands. The app tells you which side to take at every fork of the talent grid – and whether another position fits better.'),
              style: t.textTheme.bodySmall,
            ),
          ),
          // ---------- Held ----------
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ListTile(
              onTap: h == null ? _waehle : _bearbeiten,
              leading: h == null
                  ? const CircleAvatar(child: Icon(Icons.add))
                  : HeldBild(h, groesse: 48),
              title: Text(h == null ? tx('Held wählen', 'Pick hero') : h.anzeigeName),
              subtitle: h == null || _stand == null
                  ? null
                  : Text([
                      'Lv ${_stand!.level}',
                      if (_stand!.kurz(h).isNotEmpty) _stand!.kurz(h),
                      '${tx('Stärke', 'Power')} ${_stand!.kraft(db, h)}',
                      h.klasse,
                    ].join(' · ')),
              trailing: h == null
                  ? null
                  : IconButton(
                      tooltip: tx('Anderer Held', 'Other hero'),
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: _waehle,
                    ),
            ),
          ),
          if (h != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Text(tx('Antippen = Kostüm, Level, LB, Talent einstellen', 'Tap = set costume, level, LB, talent'),
                  style: t.textTheme.bodySmall),
            ),
          // ---------- Einsatz / Position ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(tx('Wofür setzt du ihn ein?', 'What do you use it for?'), style: t.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(spacing: 6, runSpacing: 4, children: [
              for (final e in Einsatz.values)
                ChoiceChip(
                  label: Text(einsatzName(e)),
                  selected: _einsatz == e,
                  onSelected: (_) => setState(() => _einsatz = e),
                ),
            ]),
          ),
          if (_einsatz == Einsatz.verteidigung) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(tx('Position in der Verteidigung', 'Position in defense'), style: t.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                for (final p in const ['flanke', 'fluegel', 'tank'])
                  ChoiceChip(
                    label: Text(positionName(p)),
                    selected: _position == p,
                    onSelected: (_) => setState(() => _position = p),
                  ),
              ]),
            ),
          ],
          SwitchListTile(
            dense: true,
            title: Text(tx('Meister-Talente (21–25) einbeziehen', 'Include master talents (21–25)')),
            value: _meister,
            onChanged: (v) => setState(() => _meister = v),
          ),
          if (h != null)
            FutureBuilder<Map<String, TalentRaster>>(
              future: _raster,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                }
                final raster = snap.data![h.klasseKey];
                if (raster == null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tx('Für die Klasse „${h.klasse}“ gibt es kein Talent-Raster.', 'No talent grid for class "${h.klasse}".')),
                  );
                }
                final werte = (_stand ?? GegnerStand.standard(h)).werte(db, h);
                final emp = TalentAnalyse.empfehlen(h, raster, werte, _einsatz, _position, meister: _meister);
                return _ergebnis(t, h, emp);
              },
            ),
        ],
      ),
    );
  }

  Widget _ergebnis(ThemeData t, Held h, TalentEmpfehlung emp) {
    final talent = _stand?.talent ?? 0;
    final kinder = <Widget>[];

    // ---------- Position ----------
    if (_einsatz == Einsatz.verteidigung && emp.positionen.isNotEmpty) {
      final beste = emp.positionen.first;
      final gewaehlt = emp.positionen.firstWhere((p) => p.position == _position);
      final besser = beste.position != _position && beste.wert - gewaehlt.wert >= 0.8;
      kinder.add(Card(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        color: besser ? Colors.orange.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(besser ? Icons.swap_vert : Icons.check_circle, color: besser ? Colors.orange : Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  besser
                      ? tx('Besser als ${positionName(beste.position)}', 'Better as ${positionName(beste.position)}')
                      : tx('${positionName(_position)} passt', '${positionName(_position)} fits'),
                  style: t.textTheme.titleMedium,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            for (final g in (besser ? beste.gruende : gewaehlt.gruende).take(4))
              Text('• ${h.nameL} $g', style: t.textTheme.bodySmall),
            if (besser)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _position = beste.position),
                  child: Text(tx('Auf ${positionName(beste.position)} umstellen', 'Switch to ${positionName(beste.position)}')),
                ),
              ),
          ]),
        ),
      ));
    }

    // ---------- Prioritäten ----------
    kinder.add(Abschnitt(tx('Worauf es ankommt', 'What matters'), icon: Icons.insights, kinder: [
      Text(emp.gewichte.reihenfolge, style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.primary)),
      const SizedBox(height: 4),
      for (final g in emp.gewichte.gruende) Text('• $g', style: t.textTheme.bodySmall),
    ]));

    // ---------- Gabelungen ----------
    kinder.add(Abschnitt(tx('Talent-Weg (${h.klasse})', 'Talent path (${h.klasse})'), icon: Icons.account_tree, kinder: [
      Text(
        tx('An jeder Gabelung nimmst du im Spiel die linke oder rechte Seite. Pflicht-Knoten (Klassen-Talent usw.) sind nicht aufgeführt.',
            'At each fork you take the left or right side in the game. Mandatory nodes (class talent etc.) are not listed.'),
        style: t.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      for (final g in emp.gabeln) _gabelZeile(t, g, talent),
    ]));

    // ---------- Summe ----------
    final s = emp.summe;
    kinder.add(Abschnitt(tx('Das bringt der Weg insgesamt', 'What the path adds in total'), icon: Icons.add_chart, kinder: [
      Wrap(spacing: 12, runSpacing: 6, children: [
        _wert(t, tx('Angriff', 'Attack'), '+${s['atk']}'),
        _wert(t, tx('Verteidigung', 'Defense'), '+${s['def']}'),
        _wert(t, tx('Leben', 'Health'), '+${s['hp']}'),
        if ((s['mana'] ?? 0) > 0) _wert(t, 'Mana', '+${s['mana']} %'),
        if ((s['crit'] ?? 0) > 0) _wert(t, tx('Krit', 'Crit'), '+${s['crit']} %'),
        if ((s['heal'] ?? 0) > 0) _wert(t, tx('Heilung', 'Healing'), '+${s['heal']} %'),
      ]),
      const SizedBox(height: 6),
      Text(
        tx('Prozent-Knoten sind mit den Werten deines Helden umgerechnet. Talente erhöhen die Werte, aber nicht die angezeigte Stärke (die steigt nur um 5 je Talentpunkt).',
            'Percent nodes are converted with your hero\'s stats. Talents raise stats but not the shown power (that only rises by 5 per talent point).'),
        style: t.textTheme.bodySmall,
      ),
    ]));

    kinder.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(tx('Talent-Raster: HeroPlan (heroplan.github.io, GPL-3.0)', 'Talent grids: HeroPlan (heroplan.github.io, GPL-3.0)'),
          style: t.textTheme.bodySmall?.copyWith(color: t.disabledColor)),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kinder);
  }

  Widget _gabelZeile(ThemeData t, GabelEmpfehlung g, int talent) {
    final nr = g.gabel.links.map((k) => k.nr).toList();
    final bereich = nr.length == 1 ? '${nr.first}' : '${nr.first}–${nr.last}';
    final erledigt = talent >= nr.last;
    Widget seite(String titel, List<TalentKnoten> k, bool gewaehlt) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: gewaehlt ? t.colorScheme.primary.withValues(alpha: 0.15) : null,
              border: Border.all(color: gewaehlt ? t.colorScheme.primary : t.dividerColor, width: gewaehlt ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(titel, style: t.textTheme.labelSmall),
                const Spacer(),
                if (gewaehlt) Icon(Icons.check, size: 16, color: t.colorScheme.primary),
              ]),
              for (final x in k)
                Text(x.text, style: gewaehlt ? t.textTheme.bodyMedium : t.textTheme.bodySmall?.copyWith(color: t.disabledColor)),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tx('Knoten $bereich', 'Nodes $bereich'), style: t.textTheme.titleSmall),
          if (g.gabel.meister) Text(tx('  · Meister', '  · master'), style: t.textTheme.bodySmall),
          const Spacer(),
          if (erledigt) Text(tx('schon gesetzt', 'already set'), style: t.textTheme.bodySmall?.copyWith(color: Colors.green)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          seite(tx('LINKS', 'LEFT'), g.gabel.links, g.links),
          const SizedBox(width: 8),
          seite(tx('RECHTS', 'RIGHT'), g.gabel.rechts, !g.links),
        ]),
        if (g.knapp)
          Text(tx('Beide Seiten sind fast gleich gut – nimm, was dir lieber ist.', 'Both sides are almost equal – take what you prefer.'),
              style: t.textTheme.bodySmall?.copyWith(color: Colors.orange))
        else
          Text(tx('Wegen: ${g.grund}', 'Because of: ${g.grund}'), style: t.textTheme.bodySmall),
      ]),
    );
  }

  Widget _wert(ThemeData t, String name, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v, style: t.textTheme.titleMedium),
        Text(name, style: t.textTheme.bodySmall),
      ]);
}
