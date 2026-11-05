// E&P Team-Analyzer – Helden per Namen eintippen
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import '../daten/namen_suche.dart';
import 'bestaetigung.dart';

class EingabeText extends StatefulWidget {
  final Datenbank db;
  const EingabeText({super.key, required this.db});

  @override
  State<EingabeText> createState() => _EingabeTextState();
}

class _EingabeTextState extends State<EingabeText> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _weiter() {
    final zeilen = zeilenLesen(_text.text);
    if (zeilen.isEmpty) return;
    final funde = [
      for (final z in zeilen)
        Fund(quelle: z.text, kandidaten: sucheNamen(widget.db, z.name), anzahl: z.anzahl),
    ];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BestaetigungSeite(db: widget.db, funde: funde, titel: tx('Eingetippte Helden', 'Typed heroes')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tx('Namen eintippen', 'Type names'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tx('Ein Held pro Zeile (oder mit Komma getrennt). Deutsche oder englische Namen, kleine Tippfehler sind egal. Mehrere Exemplare: "2x Vivica" oder "Vivica x2".',
                  'One hero per line (or comma separated). German or English names, small typos are fine. Several copies: "2x Vivica" or "Vivica x2".'),
              style: t.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _text,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Vivica\nKiril\n2x Proteus\nTelluria',
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _weiter,
              icon: const Icon(Icons.search),
              label: Text(tx('Helden suchen', 'Find heroes')),
            ),
          ],
        ),
      ),
    );
  }
}
