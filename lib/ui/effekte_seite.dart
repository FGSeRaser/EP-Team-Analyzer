// E&P Team-Analyzer – Effekt-Lexikon: was gibt es, was kontert was
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import 'helden_liste.dart';
import 'widgets.dart';

class EffekteSeite extends StatelessWidget {
  final Datenbank db;
  const EffekteSeite({super.key, required this.db});

  Widget _chip(BuildContext context, String c, Map<String, int> anzahl, Color farbe) => EffektChip(
        '${db.effektName(c)} (${anzahl[c] ?? 0})',
        gruppe: db.effekte[c]?.gruppe,
        farbe: farbe,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HeldenListe(db: db, startEffekte: {c}, titel: db.effektName(c)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Wie viele Helden (ohne Kostüme) haben welchen Effekt?
    final anzahl = <String, int>{};
    for (final h in db.helden) {
      if (h.kostuemVon != null) continue;
      for (final e in h.effekte) {
        anzahl[e] = (anzahl[e] ?? 0) + 1;
      }
    }
    final gruppen = <String, List<Effekt>>{};
    for (final e in db.effekte.values) {
      gruppen.putIfAbsent(e.gruppe, () => []).add(e);
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Effekt-Lexikon'),
          bottom: const TabBar(tabs: [Tab(text: 'Konter-Tabelle'), Tab(text: 'Alle Effekte')]),
        ),
        body: TabBarView(children: [
          // ---------- Konter ----------
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Wenn der Gegner das hier hat, brauchst du einen der grünen Effekte im Team.'),
              ),
              for (final b in db.bedrohungen.values.where((b) => !b.key.startsWith('dot_')))
                Card(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: ExpansionTile(
                    leading: const Icon(Icons.warning_amber, color: Colors.orange),
                    title: Text(b.label),
                    subtitle: Text(b.tipp, maxLines: 2, overflow: TextOverflow.ellipsis),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.tipp),
                      const SizedBox(height: 8),
                      if (b.counters.isEmpty) const Text('Kein echter Konter – nur passive Immunität hilft.'),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final c in b.counters) _chip(context, c, anzahl, Colors.green),
                      ]),
                      if (b.weich.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Federt nur ab:'),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final c in b.weich) _chip(context, c, anzahl, Colors.amber),
                        ]),
                      ],
                    ],
                  ),
                ),
            ],
          ),

          // ---------- Alle Effekte ----------
          ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final g in gruppenNamen.keys)
                if (gruppen[g] != null)
                  Abschnitt(gruppenNamen[g]!, icon: gruppenIcons[g], kinder: [
                    for (final e in gruppen[g]!)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.label),
                        trailing: Text('${anzahl[e.key] ?? 0} Helden'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HeldenListe(db: db, startEffekte: {e.key}, titel: e.label),
                          ),
                        ),
                      ),
                  ]),
            ],
          ),
        ]),
      ),
    );
  }
}
