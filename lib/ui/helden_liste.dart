// E&P Team-Analyzer – Heldenliste mit Suche und Filtern
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import 'held_detail.dart';
import 'sammlung_scope.dart';
import 'widgets.dart';

enum Sortierung { kraft, name, datum, angriff, verteidigung, leben }

const Map<Sortierung, String> sortierNamen = {
  Sortierung.kraft: 'Kraft',
  Sortierung.name: 'Name',
  Sortierung.datum: 'Neueste',
  Sortierung.angriff: 'Angriff',
  Sortierung.verteidigung: 'Verteidigung',
  Sortierung.leben: 'Leben',
};

class HeldenListe extends StatefulWidget {
  final Datenbank db;

  /// Im Auswahlmodus gibt ein Tipp den Helden per Navigator.pop zurück
  final bool auswahl;

  /// Mehrfachauswahl: "Fertig" gibt List<Held> zurück
  final bool mehrfach;
  final bool nurMeineStart;
  final Set<String> startEffekte;
  final String? titel;

  const HeldenListe({
    super.key,
    required this.db,
    this.auswahl = false,
    this.mehrfach = false,
    this.nurMeineStart = false,
    this.startEffekte = const {},
    this.titel,
  });

  @override
  State<HeldenListe> createState() => _HeldenListeState();
}

class _HeldenListeState extends State<HeldenListe> {
  final _suche = TextEditingController();
  String _q = '';
  final Set<int> _sterne = {};
  final Set<String> _farben = {};
  late Set<String> _effekte;
  bool _kostueme = false;
  bool _kommende = false;
  late bool _nurMeine;
  final List<Held> _markiert = [];
  Sortierung _sort = Sortierung.kraft;

  bool get _waehlt => widget.auswahl || widget.mehrfach;

  @override
  void initState() {
    super.initState();
    _effekte = {...widget.startEffekte};
    _nurMeine = widget.nurMeineStart;
  }

  @override
  void dispose() {
    _suche.dispose();
    super.dispose();
  }

  List<Held> _gefiltert(Set<String> meine) {
    final l = widget.db.helden.where((h) {
      if (_nurMeine) {
        if (!meine.contains(h.id)) return false;
      } else {
        if (!_kostueme && h.kostuemVon != null) return false;
        if (!_kommende && h.kommend) return false;
      }
      if (_sterne.isNotEmpty && !_sterne.contains(h.sterne)) return false;
      if (_farben.isNotEmpty && !_farben.contains(h.element)) return false;
      if (_effekte.isNotEmpty && !_effekte.every(h.effekte.contains)) return false;
      return h.passtZuSuche(_q);
    }).toList();
    switch (_sort) {
      case Sortierung.kraft:
        l.sort((a, b) => b.kraft.compareTo(a.kraft));
      case Sortierung.name:
        l.sort((a, b) => a.anzeigeName.toLowerCase().compareTo(b.anzeigeName.toLowerCase()));
      case Sortierung.datum:
        l.sort((a, b) => b.datum.compareTo(a.datum));
      case Sortierung.angriff:
        l.sort((a, b) => b.angriff.compareTo(a.angriff));
      case Sortierung.verteidigung:
        l.sort((a, b) => b.verteidigung.compareTo(a.verteidigung));
      case Sortierung.leben:
        l.sort((a, b) => b.leben.compareTo(a.leben));
    }
    return l;
  }

  Future<void> _effektFilterWaehlen() async {
    final auswahl = {..._effekte};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final gruppen = <String, List<Effekt>>{};
          for (final e in widget.db.effekte.values) {
            gruppen.putIfAbsent(e.gruppe, () => []).add(e);
          }
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            builder: (ctx, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Row(children: [
                  Expanded(
                    child: Text('Effekte filtern', style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => setSheet(auswahl.clear),
                    child: const Text('Zurücksetzen'),
                  ),
                ]),
                const Text('Held muss ALLE gewählten Effekte haben.'),
                for (final g in gruppenNamen.keys)
                  if (gruppen[g] != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Row(children: [
                        Icon(gruppenIcons[g], size: 18),
                        const SizedBox(width: 6),
                        Text(gruppenNamen[g]!, style: Theme.of(ctx).textTheme.titleSmall),
                      ]),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in gruppen[g]!)
                          FilterChip(
                            label: Text(e.label),
                            selected: auswahl.contains(e.key),
                            onSelected: (an) => setSheet(() {
                              if (an) {
                                auswahl.add(e.key);
                              } else {
                                auswahl.remove(e.key);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Übernehmen'),
                ),
              ],
            ),
          );
        },
      ),
    );
    setState(() => _effekte = auswahl);
  }

  @override
  Widget build(BuildContext context) {
    final sammlung = SammlungScope.of(context);
    final meine = sammlung.ids;
    final liste = _gefiltert(meine);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel ?? (_waehlt ? 'Helden auswählen' : 'Helden-Datenbank')),
        actions: [
          if (widget.mehrfach)
            TextButton(
              onPressed: _markiert.isEmpty ? null : () => Navigator.pop(context, List<Held>.from(_markiert)),
              child: Text('Fertig (${_markiert.length})'),
            ),
          PopupMenuButton<Sortierung>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sortieren',
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              for (final s in Sortierung.values)
                PopupMenuItem(value: s, child: Text('Nach ${sortierNamen[s]}')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _suche,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Name, Titel oder Fähigkeit suchen …',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _suche.clear();
                          _q = '';
                        }),
                      ),
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                if (meine.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilterChip(
                      avatar: const Icon(Icons.inventory_2, size: 16),
                      label: Text('Meine (${meine.length})'),
                      selected: _nurMeine,
                      onSelected: (an) => setState(() => _nurMeine = an),
                    ),
                  ),
                for (final s in [5, 4, 3])
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilterChip(
                      label: Text('$s★'),
                      selected: _sterne.contains(s),
                      onSelected: (an) => setState(() => an ? _sterne.add(s) : _sterne.remove(s)),
                    ),
                  ),
                for (final f in elementFarben.keys)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilterChip(
                      avatar: CircleAvatar(backgroundColor: elementFarben[f], radius: 7),
                      label: Text(elementNamen[f]!),
                      selected: _farben.contains(f),
                      onSelected: (an) => setState(() => an ? _farben.add(f) : _farben.remove(f)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: FilterChip(
                    label: const Text('Kostüme'),
                    selected: _kostueme,
                    onSelected: (an) => setState(() => _kostueme = an),
                  ),
                ),
                if (!_waehlt)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilterChip(
                      label: const Text('Kommende'),
                      selected: _kommende,
                      onSelected: (an) => setState(() => _kommende = an),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              ActionChip(
                avatar: const Icon(Icons.tune, size: 18),
                label: Text(_effekte.isEmpty ? 'Effekte' : 'Effekte (${_effekte.length})'),
                onPressed: _effektFilterWaehlen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${liste.length} Helden',
                    textAlign: TextAlign.end, style: t.textTheme.bodySmall),
              ),
            ]),
          ),
          if (_effekte.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final e in _effekte)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: InputChip(
                        label: Text(widget.db.effektName(e)),
                        onDeleted: () => setState(() => _effekte.remove(e)),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 8),
          Expanded(
            child: liste.isEmpty
                ? const Center(child: Text('Keine Helden gefunden.'))
                : ListView.builder(
                    itemCount: liste.length,
                    itemBuilder: (ctx, i) {
                      final h = liste[i];
                      final markiert = _markiert.contains(h);
                      return HeldKachel(
                        h,
                        trailing: widget.mehrfach
                            ? Icon(markiert ? Icons.check_circle : Icons.add_circle_outline,
                                color: markiert ? Colors.greenAccent : null)
                            : (meine.contains(h.id)
                                ? Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.inventory_2, size: 16),
                                    const SizedBox(width: 4),
                                    Text('${h.kraft}',
                                        style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
                                  ])
                                : null),
                        onTap: () {
                          if (widget.mehrfach) {
                            setState(() {
                              if (markiert) {
                                _markiert.remove(h);
                              } else {
                                _markiert.add(h);
                              }
                            });
                          } else if (widget.auswahl) {
                            Navigator.pop(context, h);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => HeldDetail(db: widget.db, held: h)),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
