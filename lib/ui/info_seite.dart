// E&P Team-Analyzer – Info & Credits
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../daten/datenbank.dart';
import 'widgets.dart';

const String githubProfil = 'https://github.com/FGSeRaser';

Future<void> oeffneLink(String url) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class InfoSeite extends StatelessWidget {
  final Datenbank db;
  const InfoSeite({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final basis = db.helden.where((h) => h.kostuemVon == null).length;
    final kostueme = db.helden.length - basis;
    return Scaffold(
      appBar: AppBar(title: const Text('Info')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Icon(Icons.shield_moon, size: 64, color: t.colorScheme.primary),
              const SizedBox(height: 8),
              Text('E&P Team-Analyzer', style: t.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('von FGSeRaser', style: t.textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('github.com/FGSeRaser'),
                onPressed: () => oeffneLink(githubProfil),
              ),
            ]),
          ),
          Abschnitt('Datenbank', icon: Icons.storage, kinder: [
            Text('$basis Helden + $kostueme Kostüme'),
            Text('${db.passive.length} passive Fähigkeiten · ${db.familien.length} Familien'),
            Text('${db.effekte.length} erkannte Effekte · ${db.bedrohungen.length} Konter-Regeln'),
            Text('Stand: ${db.version}'),
          ]),
          Abschnitt('Datenquelle', icon: Icons.source, kinder: [
            const Text(
              'Die Heldendaten stammen von HeroPlan, das sie direkt aus den offiziellen '
              'Spieldateien ausliest. Lizenz: GPL-3.0.',
            ),
            TextButton(
              onPressed: () => oeffneLink('https://heroplan.github.io'),
              child: const Text('heroplan.github.io'),
            ),
            const Text(
              'Empires & Puzzles ist eine Marke von Small Giant Games. Dies ist ein inoffizielles Fan-Tool.',
            ),
          ]),
          Abschnitt('Wie die Analyse funktioniert', icon: Icons.psychology, kinder: [
            const Text(
              'Jede Spezialfähigkeit und jede Passive wurde in Effekte zerlegt (z. B. Bannen, Reinigen, '
              'Mana-Verlangsamung). Eine Konter-Tabelle weiß, welcher Effekt welchen aushebelt. '
              'Daraus berechnet die App, wogegen ein Held oder ein Team gewappnet ist und wo Lücken sind.',
            ),
          ]),
          Abschnitt('Screenshot-Erkennung', icon: Icons.photo_camera, kinder: [
            const Text(
              'Von jedem Heldenporträt ist ein Fingerabdruck gespeichert (Mini-Bild und Farbverteilung des '
              'Gesichts). Die App sucht im Screenshot das Kartenraster, vergleicht jedes Gesicht mit allen '
              'Fingerabdrücken und schlägt die ähnlichsten Helden vor. Alles passiert auf dem Handy, '
              'es werden keine Bilder hochgeladen.',
            ),
          ]),
        ],
      ),
    );
  }
}
