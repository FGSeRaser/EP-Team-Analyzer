// E&P Team-Analyzer – Meine Helden (eigene Sammlung)
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../daten/analyse.dart';
import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/sammlung.dart';
import 'besitz_bearbeiten.dart';
import 'eingabe_screenshot.dart';
import 'eingabe_text.dart';
import 'held_detail.dart';
import 'helden_liste.dart';
import 'meine_truppen_seite.dart';
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
            title: Text(tx('Screenshots einlesen', 'Read screenshots')),
            subtitle: Text(tx('Heldenliste aus dem Spiel abfotografieren', 'Screenshot the hero list in the game')),
            onTap: () => Navigator.pop(ctx, 0),
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: Text(tx('Namen eintippen', 'Type names')),
            subtitle: Text(tx('Liste mit Heldennamen schreiben oder einfügen', 'Write or paste a list of hero names')),
            onTap: () => Navigator.pop(ctx, 1),
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: Text(tx('Aus der Datenbank wählen', 'Pick from database')),
            subtitle: Text(tx('Helden suchen und antippen', 'Search heroes and tap them')),
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('$n Helden hinzugefügt.', '$n heroes added.'))));
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
            SnackBar(content: Text(tx('Sammlung in die Zwischenablage kopiert (Sicherung).', 'Collection copied to clipboard (backup).'))),
          );
        }
      case 'import':
        final ctrl = TextEditingController();
        final text = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tx('Sicherung einfügen', 'Paste backup')),
            content: TextField(
              controller: ctrl,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '{"helden": [...]}'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(tx('Importieren', 'Import'))),
            ],
          ),
        );
        if (text == null || text.trim().isEmpty) return;
        try {
          final n = await sammlung.importieren(text, ersetzen: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('$n Helden importiert.', '$n heroes imported.'))));
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tx('Das ist keine gültige Sicherung.', 'That is not a valid backup.'))),
            );
          }
        }
      case 'leeren':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tx('Alle Helden entfernen?', 'Remove all heroes?')),
            content: Text(tx('Tipp: Vorher über „Sicherung kopieren“ sichern.', 'Tip: back up first via "Copy backup".')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx('Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tx('Alles löschen', 'Delete all'))),
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
        title: Text(tx('Meine Helden', 'My heroes')),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MeineTruppenSeite(db: widget.db))),
            icon: const Icon(Icons.shield),
            label: Text('${tx('Truppen', 'Troops')} (${sammlung.truppen.length})'),
          ),
          PopupMenuButton<String>(
            onSelected: (a) => _menue(a, sammlung),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'export', child: Text(tx('Sicherung kopieren', 'Copy backup'))),
              PopupMenuItem(value: 'import', child: Text(tx('Sicherung einfügen', 'Paste backup'))),
              PopupMenuItem(value: 'leeren', child: Text(tx('Alles löschen', 'Delete all'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _hinzufuegenMenue,
        icon: const Icon(Icons.add),
        label: Text(tx('Helden hinzufügen', 'Add heroes')),
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
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: tx('In meinen Helden suchen …', 'Search my heroes …'),
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
  int _staerke(MapEntry<Held, Besitz> e) => SammlungScope.lesen(context).staerke(widget.db, e.key, e.value);

  Widget _leer(ThemeData t) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.inventory_2_outlined, size: 72, color: t.colorScheme.primary),
          const SizedBox(height: 12),
          Text(tx('Noch keine Helden gespeichert', 'No heroes saved yet'), textAlign: TextAlign.center, style: t.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            tx('Trag deine Helden ein, dann zeigt dir die App, wogegen deine Sammlung gewappnet ist und welche Helden dir noch fehlen.',
                'Add your heroes and the app shows what your collection is prepared for and which heroes you are missing.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EingabeScreenshot(db: widget.db))),
            icon: const Icon(Icons.photo_library),
            label: Text(tx('Screenshots einlesen', 'Read screenshots')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EingabeText(db: widget.db))),
            icon: const Icon(Icons.keyboard),
            label: Text(tx('Namen eintippen', 'Type names')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _hinzufuegenMenue,
            icon: const Icon(Icons.checklist),
            label: Text(tx('Aus der Datenbank wählen', 'Pick from database')),
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
    return Abschnitt(tx('$gesamt Helden (${eintraege.length} verschiedene)', '$gesamt heroes (${eintraege.length} different)'), icon: Icons.inventory_2, kinder: [
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
              label: Text('${elementName(f)}: ${farben[f]}'),
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
        title: Text(tx('Sammlungs-Check', 'Collection check')),
        subtitle: Text(
          tx('${punkte.where((p) => p.hart.isEmpty).length} Bedrohungen ohne echten Konter', '${punkte.where((p) => p.hart.isEmpty).length} threats without a real counter'),
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
                    ? p.hart.take(4).map((h) => h.nameL).join(', ')
                    : (p.weich.isNotEmpty
                        ? '${tx('Nur abgefedert', 'Only softened')}: ${p.weich.take(3).map((h) => h.nameL).join(', ')}'
                        : tx('Keiner deiner Helden kontert das', 'None of your heroes counters this')),
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
          child: Text(tx('Kontern wirklich', 'Real counters'), style: t.textTheme.titleSmall),
        ),
        for (final h in punkt.hart)
          HeldKachel(h, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h)))),
        if (punkt.weich.isNotEmpty) Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(tx('Federn nur ab', 'Only soften'), style: t.textTheme.titleSmall),
        ),
        for (final h in punkt.weich)
          HeldKachel(h, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h)))),
        if (punkt.hart.isEmpty && b != null && b.counters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: Text(tx('Welche Helden würden helfen?', 'Which heroes would help?')),
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
