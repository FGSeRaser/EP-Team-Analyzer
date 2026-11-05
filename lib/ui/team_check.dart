// E&P Team-Analyzer – Team-Check: 5 Helden wählen, Stärken und Lücken sehen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/analyse.dart';
import '../daten/team_builder.dart';
import '../daten/truppen.dart';
import '../daten/truppen_besitz.dart';
import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import 'held_detail.dart';
import 'helden_liste.dart';
import 'meine_truppen_seite.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

class TeamCheck extends StatefulWidget {
  final Datenbank db;

  /// Optional: Team, mit dem die Seite startet (z. B. aus dem Team-Builder)
  final List<Held> start;

  /// Optional: Truppen je Held-ID (z. B. aus dem Team-Builder)
  final Map<String, EigeneTruppe> startTruppen;
  const TeamCheck({super.key, required this.db, this.start = const [], this.startTruppen = const {}});

  @override
  State<TeamCheck> createState() => _TeamCheckState();
}

class _TeamCheckState extends State<TeamCheck> {
  final List<Held?> _slots = List<Held?>.filled(5, null);
  final List<EigeneTruppe?> _truppen = List<EigeneTruppe?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.start.length && i < 5; i++) {
      _slots[i] = widget.start[i];
      _truppen[i] = widget.startTruppen[widget.start[i].id];
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
    if (h != null) {
      setState(() {
        _slots[i] = h;
        if (_truppen[i] != null && _truppen[i]!.farbe != h.element) _truppen[i] = null;
      });
    }
  }

  /// Truppe für Platz i auswählen (nur Truppen in der Farbe des Helden)
  Future<void> _truppeWaehlen(int i) async {
    final h = _slots[i];
    if (h == null) return;
    final sammlung = SammlungScope.lesen(context);
    final w = truppenVon(widget.db);
    final passend = sammlung.truppen.where((x) => x.farbe == h.element).toList()
      ..sort((a, b) => w.truppenWert(b, h, Modus.angriff, Analyse(widget.db).rollenWerte(h))
          .compareTo(w.truppenWert(a, h, Modus.angriff, Analyse(widget.db).rollenWerte(h))));
    final wahl = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(tx('Truppe für ${h.nameL} (${elementName(h.element)})', 'Troop for ${h.nameL} (${elementName(h.element)})'),
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          if (passend.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tx('Keine Truppe in dieser Farbe eingetragen – unter „Meine → Truppen“ hinzufügen.',
                  'No troop of this color yet – add one under "Mine → Troops".')),
            ),
          for (final tr in passend)
            ListTile(
              leading: const Icon(Icons.shield),
              title: Text('${tr.typName(w)} · Level ${tr.level}'),
              subtitle: Text([
                if (tr.manaProzent(w) > 0) 'Mana +${tr.manaProzent(w)} %',
                if (tr.kritProzent(w) > 0) '${tx('Krit', 'Crit')} ${tr.kritProzent(w)} %',
                if (tr.umgehenProzent(w) > 0) '${tx('Umgehen', 'Bypass')} ${tr.umgehenProzent(w)} %',
              ].join(' · ')),
              onTap: () => Navigator.pop(ctx, tr),
            ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(tx('Neue Truppe eintragen …', 'Add a new troop …')),
            onTap: () => Navigator.pop(ctx, 'neu'),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(tx('Keine Truppe', 'No troop')),
            onTap: () => Navigator.pop(ctx, 'keine'),
          ),
        ]),
      ),
    );
    if (wahl == null || !mounted) return;
    if (wahl == 'neu') {
      final neu = await truppeBearbeiten(context, widget.db, null, farbe: h.element);
      if (neu != null && neu.farbe == h.element) setState(() => _truppen[i] = neu);
      return;
    }
    setState(() => _truppen[i] = wahl is EigeneTruppe ? wahl : null);
  }

  void _truppenAutomatisch() {
    final team = _slots.whereType<Held>().toList();
    final b = TeamBuilder(Analyse(widget.db), truppenInventar: SammlungScope.lesen(context).truppen);
    final zuteilung = b.truppenZuteilen(team, Modus.angriff);
    setState(() {
      for (var i = 0; i < 5; i++) {
        final h = _slots[i];
        _truppen[i] = h == null ? null : zuteilung[h.id];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final team = _slots.whereType<Held>().toList();
    final db = widget.db;
    final truppenMap = <String, EigeneTruppe>{
      for (var i = 0; i < 5; i++)
        if (_slots[i] != null && _truppen[i] != null) _slots[i]!.id: _truppen[i]!,
    };
    // Truppen-Fähigkeiten (Krit, Umgehen, legendäre Passive) zählen in der Analyse mit
    final bericht = Analyse(db).team(truppenVon(db).teamMitTruppen(team, truppenMap));

    return Scaffold(
      appBar: AppBar(
        title: Text(tx('Team-Check', 'Team check')),
        actions: [
          if (team.isNotEmpty && SammlungScope.of(context).truppen.isNotEmpty)
            IconButton(
              tooltip: tx('Truppen automatisch verteilen', 'Assign troops automatically'),
              icon: const Icon(Icons.shield),
              onPressed: _truppenAutomatisch,
            ),
          if (team.isNotEmpty)
            IconButton(
              tooltip: tx('Leeren', 'Clear'),
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => setState(() {
                _slots.fillRange(0, 5, null);
                _truppen.fillRange(0, 5, null);
              }),
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
                            onTap: () => _truppeWaehlen(i),
                            child: Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: elementFarbe(_slots[i]!.element).withAlpha(150)),
                              ),
                              child: Text(
                                _truppen[i]?.kurz(truppenVon(db)) ?? tx('+ Truppe', '+ Troop'),
                                style: t.textTheme.labelSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        if (_slots[i] != null)
                          InkWell(
                            onTap: () => setState(() {
                              _slots[i] = null;
                              _truppen[i] = null;
                            }),
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
            Abschnitt(tx('Truppen', 'Troops'), icon: Icons.shield, kinder: [
              Text(
                tx('Tippe bei jedem Helden auf „Truppe“. Ihre Fähigkeiten (Krit, Boni umgehen, legendäre Passive, Mana) werden unten in der Analyse mitgerechnet.',
                    'Tap "Troop" for each hero. Its abilities (crit, bypass, legendary passives, mana) are included in the analysis below.'),
                style: t.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < 5; i++)
                if (_slots[i] != null) _truppenZeile(t, i, _slots[i]!, _truppen[i]),
              if (SammlungScope.of(context).truppen.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _truppenAutomatisch,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(tx('Automatisch verteilen', 'Assign automatically')),
                  ),
                ),
            ]),
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

  Widget _truppenZeile(ThemeData t, int platz, Held h, EigeneTruppe? tr) {
    final w = truppenVon(widget.db);
    final effekte = tr == null ? null : w.truppenEffekte(tr, h);
    final ohne = w.steine(h, 0);
    final mit = tr == null ? null : w.steine(h, tr.manaProzent(w));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        HeldBild(h, groesse: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.nameL, style: t.textTheme.titleSmall),
            Text(tr == null ? tx('Keine Truppe', 'No troop') : '${tr.typName(w)} · Level ${tr.level}'),
            if (effekte != null && effekte.texte.isNotEmpty)
              Text(effekte.texte.join(' · '), style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.primary)),
            if (ohne != null && mit != null && mit != ohne)
              Text(tx('$ohne → $mit Steine bis zur Spezialfähigkeit', '$ohne → $mit tiles to the special'),
                  style: t.textTheme.bodySmall?.copyWith(color: Colors.green)),
          ]),
        ),
        OutlinedButton(
          onPressed: () => _truppeWaehlen(platz),
          child: Text(tr == null ? tx('Truppe', 'Troop') : tx('Ändern', 'Change')),
        ),
      ]),
    );
  }
}
