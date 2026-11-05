// E&P Team-Analyzer – Anzeige eines Team-Vorschlags
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/team_builder.dart';
import '../daten/truppen.dart';
import '../daten/truppen_besitz.dart';
import 'held_detail.dart';
import 'team_check.dart';
import 'widgets.dart';

Color chancenFarbe(int c) => c >= 65
    ? Colors.green
    : c >= 45
        ? Colors.amber
        : c >= 25
            ? Colors.orange
            : Colors.redAccent;

class TeamKarte extends StatelessWidget {
  final Datenbank db;
  final TeamVorschlag v;
  final String titel;
  final bool positionen;
  const TeamKarte({super.key, required this.db, required this.v, required this.titel, this.positionen = false});

  static List<String> get _pos => [
        tx('Flanke', 'Flank'),
        tx('Flügel', 'Wing'),
        'Tank',
        tx('Flügel', 'Wing'),
        tx('Flanke', 'Flank'),
      ];

  /// "(10 → 9 Steine)", wenn die Truppe eine Mana-Schwelle knackt
  String _steine(Held h, EigeneTruppe tr) {
    final w = truppenVon(db);
    final ohne = w.steine(h, 0);
    final mit = w.steine(h, tr.manaProzent(w));
    if (ohne == null || mit == null || mit == ohne) return '';
    return tx(' ($ohne → $mit Steine)', ' ($ohne → $mit tiles)');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(titel, style: t.textTheme.titleMedium)),
            if (v.chance != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chancenFarbe(v.chance!).withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: chancenFarbe(v.chance!)),
                ),
                child: Text('~${v.chance} %',
                    style: t.textTheme.titleMedium?.copyWith(color: chancenFarbe(v.chance!))),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < v.helden.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: v.helden[i])),
                  ),
                  child: Column(children: [
                    HeldBild(v.helden[i], groesse: 52),
                    const SizedBox(height: 3),
                    Text(v.helden[i].nameL,
                        style: t.textTheme.labelSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                    if (positionen && v.helden.length == 5)
                      Text(_pos[i], style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.primary)),
                    if (v.truppen[v.helden[i].id] != null)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: elementFarbe(v.helden[i].element).withAlpha(60),
                        ),
                        child: Text(v.truppen[v.helden[i].id]!.kurz(truppenVon(db)),
                            style: t.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ]),
                ),
              ),
          ]),
          if (v.aufgaben.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final h in v.helden)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${h.nameL}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: v.aufgaben[h.id] ?? ''),
                  if (v.truppen[h.id] != null)
                    TextSpan(
                        text: '  ·  ${v.truppen[h.id]!.typName(truppenVon(db))} ${v.truppen[h.id]!.level}'
                            '${_steine(h, v.truppen[h.id]!)}',
                        style: t.textTheme.bodySmall),
                ]), style: t.textTheme.bodySmall),
              ),
          ],
          const SizedBox(height: 10),
          for (final s in v.staerken.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(child: Text(s, style: t.textTheme.bodySmall)),
              ]),
            ),
          for (final s in v.schwaechen.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(child: Text(s, style: t.textTheme.bodySmall)),
              ]),
            ),
          if (v.plan.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.sports_esports, size: 18, color: t.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(tx('So spielst du es', 'How to play it'),
                      style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.primary)),
                ]),
                const SizedBox(height: 6),
                for (var i = 0; i < v.plan.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 20, child: Text('${i + 1}.', style: t.textTheme.bodySmall)),
                      Expanded(child: Text(v.plan[i], style: t.textTheme.bodySmall)),
                    ]),
                  ),
              ]),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(tx('Im Team-Check öffnen', 'Open in team check')),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TeamCheck(db: db, start: v.helden, startTruppen: v.truppen)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
