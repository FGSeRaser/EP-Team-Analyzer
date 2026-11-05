// E&P Team-Analyzer – Detailseite eines Helden
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/analyse.dart';
import '../daten/datenbank.dart';
import 'besitz_bearbeiten.dart';
import 'helden_liste.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

const Map<String, String> rollenKurz = {
  'tank': 'Tank',
  'flanke': 'Flanke',
  'angreifer': 'Angreifer',
  'heiler': 'Heiler',
  'konter': 'Bannen/Kontrolle',
};

class HeldDetail extends StatelessWidget {
  final Datenbank db;
  final Held held;
  const HeldDetail({super.key, required this.db, required this.held});

  void _zeigeEffekt(BuildContext context, String key) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HeldenListe(
          db: db,
          startEffekte: {key},
          titel: db.effektName(key),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = Analyse(db);
    final farbe = elementFarbe(held.element);
    final familie = db.familien[held.familie];
    final varianten = db.varianten(held).where((v) => v.id != held.id).toList();
    final hilft = a.hilftGegen(held);
    final teilweise = a.hilftTeilweise(held);
    final anfaellig = a.anfaelligFuer(held);
    final immun = a.immunitaeten(held);
    final rollen = a.rollenWerte(held);

    // Effekte nach Gruppe sortieren
    final gruppen = <String, List<String>>{};
    for (final e in held.effekte) {
      final g = db.effekte[e]?.gruppe ?? 'sonstiges';
      gruppen.putIfAbsent(g, () => []).add(e);
    }

    final besitz = SammlungScope.of(context).besitz(held.id);

    return Scaffold(
      appBar: AppBar(title: Text(held.anzeigeName)),
      floatingActionButton: held.kommend
          ? null
          : FloatingActionButton.extended(
              onPressed: () => besitzBearbeiten(context, db, held),
              icon: Icon(besitz == null ? Icons.add : Icons.edit),
              label: Text(besitz == null ? 'Zur Sammlung' : 'In Sammlung: ${besitz.standText(held)}'),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          // ---------- Kopf ----------
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [farbe.withAlpha(90), farbe.withAlpha(15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeldBild(held, groesse: 92),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(held.anzeigeName, style: t.textTheme.headlineSmall),
                      if (held.titel.isNotEmpty)
                        Text(held.titel, style: t.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 4),
                      Sterne(held.sterne, groesse: 18),
                      const SizedBox(height: 6),
                      Wrap(spacing: 10, runSpacing: 2, children: [
                        _info(Icons.palette, elementNamen[held.element] ?? held.element),
                        _info(Icons.school, held.klasse),
                        _info(Icons.speed, held.tempo),
                        if (held.datum.isNotEmpty) _info(Icons.event, held.datum),
                      ]),
                      if (held.kommend)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              held.datum.isEmpty ? 'Noch nicht erschienen (ohne Termin)' : 'Erscheint am ${held.datum}',
                              style: TextStyle(color: t.colorScheme.tertiary)),
                        ),
                      if (held.unvollstaendig)
                        Text('Fähigkeit im Spiel noch Platzhalter',
                            style: TextStyle(color: t.colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------- Werte ----------
          Abschnitt('Werte', icon: Icons.bar_chart, kinder: [
            Table(
              columnWidths: const {0: FlexColumnWidth(1.2)},
              children: [
                _zeile(t, ['', 'Angriff', 'Verteid.', 'Leben', 'Kraft'], kopf: true),
                _zeile(t, ['Max', ...held.werte[0].map((v) => '$v')]),
                if (held.sterne >= 3) _zeile(t, ['LB1', ...held.werte[1].map((v) => '$v')]),
                if (held.sterne >= 3) _zeile(t, ['LB2', ...held.werte[2].map((v) => '$v')]),
              ],
            ),
            const SizedBox(height: 6),
            Text('Ohne Embleme und Kostümbonus.', style: t.textTheme.bodySmall),
          ]),

          // ---------- Spezialfähigkeit ----------
          Abschnitt('Spezial: ${held.spezialName}', icon: Icons.auto_awesome, kinder: [
            for (final z in held.spezial)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('•  '),
                  Expanded(child: Text(z)),
                ]),
              ),
          ]),

          // ---------- Passive ----------
          if (held.passive.isNotEmpty)
            Abschnitt('Passive Fähigkeiten', icon: Icons.all_inclusive, kinder: [
              for (final pid in held.passive)
                if (db.passive[pid] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(db.passive[pid]!.titel, style: t.textTheme.titleSmall),
                      Text(_saeubern(db.passive[pid]!.text)),
                    ]),
                  ),
            ]),

          // ---------- Effekte ----------
          Abschnitt('Was er kann', icon: Icons.category, kinder: [
            if (held.effekte.isEmpty) const Text('Keine Effekte erkannt.'),
            for (final g in gruppenNamen.keys)
              if (gruppen[g] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in gruppen[g]!)
                      EffektChip(db.effektName(e), gruppe: g, onTap: () => _zeigeEffekt(context, e)),
                  ]),
                ),
            const SizedBox(height: 4),
            Text('Tippe auf einen Effekt, um alle Helden damit zu sehen.', style: t.textTheme.bodySmall),
          ]),

          // ---------- Rollen ----------
          Abschnitt('Eignung', icon: Icons.groups, kinder: [
            for (final r in rollen.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 120, child: Text(rollenKurz[r.key] ?? r.key)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: r.value / 100, minHeight: 10),
                    ),
                  ),
                  SizedBox(width: 40, child: Text('${r.value}', textAlign: TextAlign.end)),
                ]),
              ),
            Text('Grobe Einschätzung aus Effekten und Werten.', style: t.textTheme.bodySmall),
          ]),

          // ---------- Hilft gegen ----------
          if (hilft.isNotEmpty)
            Abschnitt('Hilft dem Team gegen', icon: Icons.verified_user, kinder: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final b in hilft) EffektChip(db.bedrohungName(b), farbe: Colors.green),
              ]),
            ]),

          if (teilweise.isNotEmpty)
            Abschnitt('Federt ab', icon: Icons.shield_outlined, kinder: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final b in teilweise) EffektChip(db.bedrohungName(b), farbe: Colors.amber),
              ]),
            ]),

          // ---------- Immun ----------
          if (immun.isNotEmpty)
            Abschnitt('Selbst geschützt gegen', icon: Icons.health_and_safety, kinder: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in immun)
                  EffektChip(
                    e.value >= 1
                        ? db.bedrohungName(e.key)
                        : '${db.bedrohungName(e.key)} (${(e.value * 100).round()}%)',
                    farbe: Colors.teal,
                  ),
              ]),
            ]),

          // ---------- Anfällig ----------
          if (anfaellig.isNotEmpty)
            Abschnitt('Wird ausgehebelt durch', icon: Icons.warning_amber, kinder: [
              for (final e in anfaellig.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${db.effektName(e.key)}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: e.value.map(db.effektName).join(', ')),
                  ])),
                ),
              Text('Gegner mit diesen Effekten nehmen seinem Vorteil die Wirkung.', style: t.textTheme.bodySmall),
            ]),

          // ---------- Familie ----------
          if (familie != null && familie.bonus.isNotEmpty)
            Abschnitt('Familie: ${familie.name}', icon: Icons.family_restroom, kinder: [
              for (final z in familie.bonus) Text(_saeubern(z)),
            ]),

          if (held.aether.isNotEmpty)
            Abschnitt('Äther-Kraft', icon: Icons.bolt, kinder: [Text(held.aether)]),

          // ---------- Varianten ----------
          if (varianten.isNotEmpty)
            Abschnitt('Andere Varianten', icon: Icons.checkroom, kinder: [
              for (final v in varianten)
                HeldKachel(
                  v,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: v)),
                  ),
                ),
            ]),
        ],
      ),
    );
  }

  static String _saeubern(String s) => s.replaceAll('[*]', '• ');

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14),
        const SizedBox(width: 3),
        Text(text),
      ]);

  TableRow _zeile(ThemeData t, List<String> zellen, {bool kopf = false}) => TableRow(
        children: [
          for (final z in zellen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                z,
                textAlign: z == zellen.first ? TextAlign.start : TextAlign.end,
                style: kopf ? t.textTheme.labelMedium : t.textTheme.bodyMedium,
              ),
            ),
        ],
      );
}
