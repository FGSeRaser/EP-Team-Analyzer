// E&P Team-Analyzer – Meine Helden (eigene Sammlung)
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../daten/analyse.dart';
import '../daten/datenbank.dart';
import '../daten/sammlung.dart';
import 'besitz_bearbeiten.dart';
import 'eingabe_screenshot.dart';
import 'eingabe_text.dart';
import 'held_detail.dart';
import 'helden_liste.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

class SammlungSeite extends StatefulWidget {
  final Datenbank db;
  const SammlungSeite({super.key, required this.db});

  @override
  State<SammlungSeite> createState() => _SammlungSeiteState();
}

class _SammlungSeiteState extends State<SammlungSeite> {
  String _q = '';

  Future<void> _hinzufuegenMenue() async {
    final wahl = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Screenshots einlesen'),
            subtitle: const Text('Heldenliste aus dem Spiel abfotografieren'),
            onTap: () => Navigator.pop(ctx, 0),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text('Namen eintippen'),
            subtitle: const Text('Liste mit Heldennamen schreiben oder einfügen'),
            onTap: () => Navigator.pop(ctx, 1),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Aus der Datenbank wählen'),
            subtitle: const Text('Helden suchen und antippen'),
            onTap: () => Navigator.pop(ctx, 2),
          ),
        ]),
      ),
    );
    if (!mounted || wahl == null) return;
    switch (wahl) {
      case 0:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => EingabeScreenshot(db: widget.db)));
      case 1:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => EingabeText(db: widget.db)));
      case 2:
        final sammlung = SammlungScope.lesen(context);
        final liste = await Navigator.push<List<Held>>(
          context,
          MaterialPageRoute(builder: (_) => HeldenListe(db: widget.db, mehrfach: true)),
        );
        if (liste != null && liste.isNotEmpty) {
          final n = await sammlung.hinzufuegen(liste);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n Helden hinzugefügt.')));
          }
        }
    }
  }

  Future<void> _menue(String aktion, Sammlung sammlung) async {
    switch (aktion) {
      case 'export':
        await Clipboard.setData(ClipboardData(text: sammlung.exportieren()));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sammlung in die Zwischenablage kopiert (Sicherung).')),
          );
        }
      case 'import':
        final ctrl = TextEditingController();
        final text = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sicherung einfügen'),
            content: TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '{"helden": [...]}'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Importieren')),
            ],
          ),
        );
        if (text == null || text.trim().isEmpty) return;
        try {
          final n = await sammlung.importieren(text, ersetzen: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n Helden importiert.')));
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Das ist keine gültige Sicherung.')),
            );
          }
        }
      case 'leeren':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Alle Helden entfernen?'),
            content: const Text('Tipp: Vorher über „Sicherung kopieren“ sichern.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Alles löschen')),
            ],
          ),
        );
        if (ok == true) await sammlung.leeren();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sammlung = SammlungScope.of(context);
    final eintraege = sammlung.mitHelden(widget.db)
      ..sort((a, b) => _staerke(b).compareTo(_staerke(a)));
    final gefiltert = eintraege.where((e) => e.key.passtZuSuche(_q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Helden'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (a) => _menue(a, sammlung),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Sicherung kopieren')),
              PopupMenuItem(value: 'import', child: Text('Sicherung einfügen')),
              PopupMenuItem(value: 'leeren', child: Text('Alles löschen')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _hinzufuegenMenue,
        icon: const Icon(Icons.add),
        label: const Text('Helden hinzufügen'),
      ),
      body: eintraege.isEmpty
          ? _leer(t)
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                _ueberblick(t, eintraege),
                _check(t, eintraege.map((e) => e.key).toList()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'In meinen Helden suchen …',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  ),
                ),
                for (final e in gefiltert)
                  HeldKachel(
                    e.key,
                    onTap: () => besitzBearbeiten(context, widget.db, e.key),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${_staerke(e)}',
                            style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
                        Text(
                          '${e.value.standText(e.key)}${e.value.anzahl > 1 ? ' · ×${e.value.anzahl}' : ''}',
                          style: t.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  /// Stärke laut Spiel, sonst berechnet
  static int _staerke(MapEntry<Held, Besitz> e) => e.value.staerke ?? e.value.werte(e.key).kraft;

  Widget _leer(ThemeData t) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.inventory_2_outlined, size: 72, color: t.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Noch keine Helden gespeichert', textAlign: TextAlign.center, style: t.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Trag deine Helden ein, dann zeigt dir die App, wogegen deine Sammlung gewappnet ist '
            'und welche Helden dir noch fehlen.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EingabeScreenshot(db: widget.db))),
            icon: const Icon(Icons.photo_library),
            label: const Text('Screenshots einlesen'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EingabeText(db: widget.db))),
            icon: const Icon(Icons.keyboard),
            label: const Text('Namen eintippen'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _hinzufuegenMenue,
            icon: const Icon(Icons.checklist),
            label: const Text('Aus der Datenbank wählen'),
          ),
        ],
      );

  Widget _ueberblick(ThemeData t, List<MapEntry<Held, Besitz>> eintraege) {
    final farben = <String, int>{};
    final sterne = <int, int>{};
    var gesamt = 0;
    for (final e in eintraege) {
      farben[e.key.element] = (farben[e.key.element] ?? 0) + e.value.anzahl;
      sterne[e.key.sterne] = (sterne[e.key.sterne] ?? 0) + e.value.anzahl;
      gesamt += e.value.anzahl;
    }
    return Abschnitt('$gesamt Helden (${eintraege.length} verschiedene)', icon: Icons.inventory_2, kinder: [
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final s in [5, 4, 3, 2, 1])
          if (sterne[s] != null) Chip(label: Text('$s★: ${sterne[s]}'), visualDensity: VisualDensity.compact),
      ]),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final f in elementFarben.keys)
          if (farben[f] != null)
            Chip(
              avatar: CircleAvatar(backgroundColor: elementFarben[f], radius: 7),
              label: Text('${elementNamen[f]}: ${farben[f]}'),
              visualDensity: VisualDensity.compact,
            ),
      ]),
    ]);
  }

  Widget _check(ThemeData t, List<Held> helden) {
    final punkte = Analyse(widget.db).sammlungsCheck(helden);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: ExpansionTile(
        leading: const Icon(Icons.radar),
        title: const Text('Sammlungs-Check'),
        subtitle: Text(
          '${punkte.where((p) => p.hart.isEmpty).length} Bedrohungen ohne echten Konter',
          style: t.textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final p in punkte)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: p.hart.isEmpty
                    ? (p.weich.isEmpty ? Colors.redAccent : Colors.orange)
                    : (p.hart.length < 3 ? Colors.amber : Colors.green),
                child: Text('${p.hart.length}', style: const TextStyle(fontSize: 12, color: Colors.black)),
              ),
              title: Text(widget.db.bedrohungName(p.bedrohung)),
              subtitle: Text(
                p.hart.isNotEmpty
                    ? p.hart.take(4).map((h) => h.name).join(', ')
                    : (p.weich.isNotEmpty
                        ? 'Nur abgefedert: ${p.weich.take(3).map((h) => h.name).join(', ')}'
                        : 'Keiner deiner Helden kontert das'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _KonterListe(db: widget.db, punkt: p),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KonterListe extends StatelessWidget {
  final Datenbank db;
  final SammlungsPunkt punkt;
  const _KonterListe({required this.db, required this.punkt});

  @override
  Widget build(BuildContext context) {
    final b = db.bedrohungen[punkt.bedrohung];
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(db.bedrohungName(punkt.bedrohung))),
      body: ListView(children: [
        if (b != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(b.tipp)),
        if (punkt.hart.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Kontern wirklich', style: t.textTheme.titleSmall),
        ),
        for (final h in punkt.hart)
          HeldKachel(h, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h)))),
        if (punkt.weich.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Federn nur ab', style: t.textTheme.titleSmall),
        ),
        for (final h in punkt.weich)
          HeldKachel(h, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h)))),
        if (punkt.hart.isEmpty && b != null && b.counters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Welche Helden würden helfen?'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HeldenListe(db: db, startEffekte: {b.counters.first}, titel: db.effektName(b.counters.first)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
