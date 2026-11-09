// E&P Team-Analyzer – Übersichtsseiten "Teams" und "Wissen"
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
import 'effekte_seite.dart';
import 'chat_tool_seite.dart';
import 'gegner_seite.dart';
import 'held_analyse_seite.dart';
import 'team_builder_seite.dart';
import 'team_check.dart';
import 'truppen_seite.dart';

class _Eintrag {
  final IconData icon;
  final String titel, text;
  final Widget Function() seite;
  const _Eintrag(this.icon, this.titel, this.text, this.seite);
}

class _Bereich extends StatelessWidget {
  final String titel;
  final List<_Eintrag> eintraege;
  const _Bereich(this.titel, this.eintraege);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(titel)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final e in eintraege)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => e.seite())),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: t.colorScheme.primaryContainer,
                      child: Icon(e.icon, color: t.colorScheme.onPrimaryContainer, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.titel, style: t.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(e.text, style: t.textTheme.bodySmall),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TeamsBereich extends StatelessWidget {
  final Datenbank db;
  const TeamsBereich({super.key, required this.db});

  @override
  Widget build(BuildContext context) => _Bereich(tx('Teams', 'Teams'), [
        _Eintrag(
          Icons.auto_awesome,
          tx('Team-Builder', 'Team builder'),
          tx('Beste Teams aus deinen Helden für Verteidigung, Angriff, Krieg und Titan.',
              'Best teams from your heroes for defense, attack, war and titans.'),
          () => TeamBuilderSeite(db: db),
        ),
        _Eintrag(
          Icons.psychology,
          tx('Gegner-Analyse', 'Enemy analysis'),
          tx('Gegnerteam per Screenshot oder Auswahl – welche deiner Helden mit welcher Chance?',
              'Enemy team by screenshot or selection – which of your heroes, with what chance?'),
          () => GegnerSeite(db: db),
        ),
        _Eintrag(
          Icons.groups,
          tx('Team-Check', 'Team check'),
          tx('5 Helden selbst wählen und Stärken und Lücken sehen.', 'Pick 5 heroes yourself and see strengths and gaps.'),
          () => TeamCheck(db: db),
        ),
        _Eintrag(
          Icons.account_tree,
          'Hero-Analyser',
          tx('Beste Talente (Angriff, Verteidigung, Leben, Mana) je Held und Position – und ob eine andere Position besser passt.',
              'Best talents (attack, defense, health, mana) per hero and position – and whether another position fits better.'),
          () => HeldAnalyseSeite(db: db),
        ),
        _Eintrag(
          Icons.forum,
          tx('Chat-Tool', 'Chat tool'),
          tx('Allianz-Nachricht, Rekrutierung & Co. mit Farben und Emotes schreiben, Vorschau sehen, speichern und kopieren.',
              'Write alliance messages, recruiting & more with colors and emotes, preview, save and copy.'),
          () => const ChatToolSeite(),
        ),
      ]);
}

class WissenBereich extends StatelessWidget {
  final Datenbank db;
  const WissenBereich({super.key, required this.db});

  @override
  Widget build(BuildContext context) => _Bereich(tx('Wissen', 'Knowledge'), [
        _Eintrag(
          Icons.menu_book,
          tx('Effekte & Konter', 'Effects & counters'),
          tx('Was kontert was – und welche Helden welche Effekte haben.', 'What counters what – and which heroes have which effects.'),
          () => EffekteSeite(db: db),
        ),
        _Eintrag(
          Icons.shield,
          tx('Truppen', 'Troops'),
          tx('Alle Truppenarten, legendäre Truppen nach Klasse, Mana-Stufen.',
              'All troop types, legendary troops by class, mana levels.'),
          () => TruppenSeite(db: db),
        ),
      ]);
}
