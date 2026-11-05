// E&P Team-Analyzer – erkannte oder eingetippte Helden prüfen und übernehmen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/sammlung.dart';
import 'helden_liste.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

/// Ein Fund = eine Screenshot-Zelle oder eine eingetippte Zeile
class Fund {
  final String quelle;
  final int gruppe; // Screenshot-Nummer (für Überlappung), bei Text 0
  final ui.Image? bild;
  final Rect? rect;
  final List<Held> kandidaten;
  final List<double> werte; // Ähnlichkeit 0..1, leer bei Text
  final int anzahl;

  /// Aus dem Screenshot gelesen (Texterkennung)
  final String? textName;
  final int? level;
  final int? talent;
  final int? staerke;

  /// true = Name aus dem Text passt zum gewählten Porträt
  final bool nameBestaetigt;
  Held? gewaehlt;
  bool aktiv;

  Fund({
    required this.quelle,
    this.gruppe = 0,
    this.bild,
    this.rect,
    required this.kandidaten,
    this.werte = const [],
    this.anzahl = 1,
    this.textName,
    this.level,
    this.talent,
    this.staerke,
    this.nameBestaetigt = false,
  })  : gewaehlt = kandidaten.isEmpty ? null : kandidaten.first,
        aktiv = kandidaten.isNotEmpty;

  String get standText {
    final t = <String>[];
    if (level != null) t.add('LVL $level');
    if (talent != null) t.add('Talent $talent');
    if (staerke != null) t.add(tx('Stärke $staerke', 'Power $staerke'));
    return t.join(' · ');
  }

  /// Unsicher, wenn der Abstand zwischen Platz 1 und 2 klein ist
  bool get unsicher {
    if (kandidaten.isEmpty) return true;
    if (werte.isEmpty) return kandidaten.length > 1; // Text: mehrdeutiger Name
    if (nameBestaetigt) return werte[0] < 0.8; // Name und Bild passen zusammen
    if (werte.length < 2) return werte[0] < 0.9;
    return werte[0] - werte[1] < 0.03 || werte[0] < 0.9;
  }
}

/// Ausschnitt eines Bildes anzeigen
class ZellenBild extends StatelessWidget {
  final ui.Image bild;
  final Rect rect;
  final double breite;
  const ZellenBild(this.bild, this.rect, {super.key, this.breite = 56});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: breite,
        height: breite * rect.height / rect.width,
        child: CustomPaint(painter: _ZellenMaler(bild, rect)),
      ),
    );
  }
}

class _ZellenMaler extends CustomPainter {
  final ui.Image bild;
  final Rect rect;
  _ZellenMaler(this.bild, this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(bild, rect, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(_ZellenMaler alt) => alt.bild != bild || alt.rect != rect;
}

class BestaetigungSeite extends StatefulWidget {
  final Datenbank db;
  final List<Fund> funde;
  final String titel;
  final bool ausScreenshots;
  BestaetigungSeite({
    super.key,
    required this.db,
    required this.funde,
    this.titel = tx('Helden prüfen', 'Check heroes'),
    this.ausScreenshots = false,
  });

  @override
  State<BestaetigungSeite> createState() => _BestaetigungSeiteState();
}

class _BestaetigungSeiteState extends State<BestaetigungSeite> {
  bool _nurNeue = true;
  bool _ueberlappung = true;
  bool _nurUnsichere = false;

  NeuerHeld _neu(Fund f) => NeuerHeld(f.gewaehlt!, level: f.level, talent: f.talent, staerke: f.staerke);

  List<NeuerHeld> _zuUebernehmen() {
    final aktiv = widget.funde.where((f) => f.aktiv && f.gewaehlt != null).toList();
    if (!widget.ausScreenshots || !_ueberlappung) {
      return [
        for (final f in aktiv)
          for (var i = 0; i < f.anzahl; i++) _neu(f),
      ];
    }
    // Überlappende Screenshots: gleicher Held mit gleicher Stärke = dasselbe Exemplar.
    // Ohne gelesene Stärke: höchste Anzahl in EINEM Screenshot.
    final nachHeld = <String, List<Fund>>{};
    for (final f in aktiv) {
      nachHeld.putIfAbsent(f.gewaehlt!.id, () => []).add(f);
    }
    final out = <NeuerHeld>[];
    for (final liste in nachHeld.values) {
      if (liste.every((f) => f.staerke != null)) {
        final gesehen = <int>{};
        for (final f in liste) {
          if (gesehen.add(f.staerke!)) out.add(_neu(f));
        }
      } else {
        final proGruppe = <int, List<Fund>>{};
        for (final f in liste) {
          proGruppe.putIfAbsent(f.gruppe, () => []).add(f);
        }
        final groesste = proGruppe.values.reduce((a, b) => a.length >= b.length ? a : b);
        out.addAll(groesste.map(_neu));
      }
    }
    return out;
  }

  Future<void> _anderen(Fund f) async {
    final h = await Navigator.push<Held>(
      context,
      MaterialPageRoute(builder: (_) => HeldenListe(db: widget.db, auswahl: true)),
    );
    if (h != null) {
      setState(() {
        f.gewaehlt = h;
        f.aktiv = true;
      });
    }
  }

  Future<void> _uebernehmen() async {
    final sammlung = SammlungScope.lesen(context);
    final liste = _zuUebernehmen();
    final n = await sammlung.hinzufuegenMitStand(liste, nurNeue: _nurNeue);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tx('$n Helden zur Sammlung hinzugefügt.', '$n heroes added to the collection.'))),
    );
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sammlung = SammlungScope.of(context);
    final sichtbar = _nurUnsichere ? widget.funde.where((f) => f.unsicher).toList() : widget.funde;
    final anzahl = _zuUebernehmen().length;
    final unsicher = widget.funde.where((f) => f.unsicher).length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titel)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          SwitchListTile(
            title: Text(tx('Schon vorhandene nicht doppelt zählen', 'Don\'t count existing ones twice')),
            subtitle: Text(tx('Helden, die bereits in deiner Sammlung sind, werden übersprungen.', 'Heroes already in your collection are skipped.')),
            value: _nurNeue,
            onChanged: (v) => setState(() => _nurNeue = v),
          ),
          if (widget.ausScreenshots)
            SwitchListTile(
              title: Text(tx('Screenshots überlappen', 'Screenshots overlap')),
              subtitle: Text(tx('Gleicher Held mit gleicher Stärke auf mehreren Screenshots zählt nur einmal.', 'Same hero with the same power on several screenshots counts once.')),
              value: _ueberlappung,
              onChanged: (v) => setState(() => _ueberlappung = v),
            ),
          if (unsicher > 0)
            SwitchListTile(
              title: Text(tx('Nur unsichere zeigen ($unsicher)', 'Show only uncertain ($unsicher)')),
              value: _nurUnsichere,
              onChanged: (v) => setState(() => _nurUnsichere = v),
            ),
          const Divider(),
          for (final f in sichtbar) _fundKarte(t, f, sammlung.hat(f.gewaehlt?.id ?? '')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: anzahl == 0 ? null : _uebernehmen,
        icon: const Icon(Icons.check),
        label: Text(tx('$anzahl übernehmen', 'Add $anzahl')),
      ),
    );
  }

  Widget _fundKarte(ThemeData t, Fund f, bool vorhanden) {
    final g = f.gewaehlt;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      color: f.aktiv ? null : t.colorScheme.surfaceContainerHighest.withAlpha(90),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (f.bild != null && f.rect != null)
              ZellenBild(f.bild!, f.rect!)
            else
              SizedBox(
                width: 56,
                child: Text(f.quelle, style: t.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        g == null ? tx('Nicht gefunden', 'Not found') : g.anzeigeName,
                        style: t.textTheme.titleMedium,
                      ),
                    ),
                    Checkbox(value: f.aktiv && g != null, onChanged: g == null ? null : (v) => setState(() => f.aktiv = v ?? false)),
                  ]),
                  if (g != null)
                    Row(children: [
                      Sterne(g.sterne, groesse: 12),
                      const SizedBox(width: 6),
                      Text(elementName(g.element), style: t.textTheme.bodySmall),
                      if (f.anzahl > 1) Text('  ×${f.anzahl}', style: t.textTheme.bodySmall),
                      if (vorhanden)
                        Text(tx('  · schon in Sammlung', '  · already in collection'), style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.tertiary)),
                    ]),
                  if (f.standText.isNotEmpty || f.textName != null)
                    Text(
                      [
                        if (f.textName != null) '${tx('gelesen', 'read')}: „${f.textName}“${f.nameBestaetigt ? ' ✓' : ''}',
                        if (f.standText.isNotEmpty) f.standText,
                      ].join(' · '),
                      style: t.textTheme.bodySmall,
                    ),
                  if (f.unsicher && g != null)
                    Text(tx('Unsicher – bitte prüfen', 'Uncertain – please check'), style: t.textTheme.bodySmall?.copyWith(color: Colors.orange)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (var i = 0; i < f.kandidaten.length && i < 5; i++)
                      ChoiceChip(
                        avatar: HeldBild(f.kandidaten[i], groesse: 24),
                        label: Text(
                          f.werte.length > i
                              ? '${f.kandidaten[i].anzeigeName} ${(f.werte[i] * 100).round()}%'
                              : f.kandidaten[i].anzeigeName,
                        ),
                        selected: identical(f.kandidaten[i], g),
                        onSelected: (_) => setState(() {
                          f.gewaehlt = f.kandidaten[i];
                          f.aktiv = true;
                        }),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.search, size: 18),
                      label: Text(tx('Anderer …', 'Other …')),
                      onPressed: () => _anderen(f),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
