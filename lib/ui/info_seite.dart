// E&P Team-Analyzer – Info, Sprache & Credits
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../daten/datenbank.dart';
import '../daten/sprache.dart';
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
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/icon/icon.png', width: 96, height: 96),
              ),
              const SizedBox(height: 10),
              Text('E&P Team-Analyzer', style: t.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(tx('von FGSeRaser', 'by FGSeRaser'), style: t.textTheme.titleMedium),
              TextButton.icon(
                icon: const Icon(Icons.code),
                label: const Text('github.com/FGSeRaser'),
                onPressed: () => oeffneLink(githubProfil),
              ),
            ]),
          ),
          Abschnitt(tx('Sprache', 'Language'), icon: Icons.language, kinder: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Deutsch')),
                ButtonSegment(value: true, label: Text('English')),
              ],
              selected: {Sprache.en},
              onSelectionChanged: (v) => Sprache.instanz.setzen(v.first),
            ),
          ]),
          Abschnitt(tx('Datenbank', 'Database'), icon: Icons.storage, kinder: [
            Text(tx('$basis Helden + $kostueme Kostüme', '$basis heroes + $kostueme costumes')),
            Text(tx('${db.passive.length} passive Fähigkeiten · ${db.familien.length} Familien',
                '${db.passive.length} passive skills · ${db.familien.length} families')),
            Text(tx('${db.effekte.length} erkannte Effekte · ${db.bedrohungen.length} Konter-Regeln',
                '${db.effekte.length} detected effects · ${db.bedrohungen.length} counter rules')),
            Text('${tx('Stand', 'As of')}: ${db.version}'),
          ]),
          Abschnitt(tx('Datenquelle', 'Data source'), icon: Icons.source, kinder: [
            Text(tx(
              'Die Heldendaten stammen von HeroPlan, das sie direkt aus den offiziellen Spieldateien ausliest. Lizenz: GPL-3.0. Truppenwissen nach empuzzled.com.',
              'Hero data comes from HeroPlan, read directly from the official game files. License: GPL-3.0. Troop knowledge based on empuzzled.com.',
            )),
            TextButton(
              onPressed: () => oeffneLink('https://heroplan.github.io'),
              child: const Text('heroplan.github.io'),
            ),
            Text(tx(
              'Empires & Puzzles ist eine Marke von Small Giant Games. Dies ist ein inoffizielles Fan-Tool.',
              'Empires & Puzzles is a trademark of Small Giant Games. This is an unofficial fan tool.',
            )),
          ]),
          Abschnitt(tx('Wie die Analyse funktioniert', 'How the analysis works'), icon: Icons.psychology, kinder: [
            Text(tx(
              'Jede Spezialfähigkeit und jede Passive wurde in Effekte zerlegt (z. B. Bannen, Reinigen, Mana-Verlangsamung). '
                  'Eine Konter-Tabelle weiß, welcher Effekt welchen aushebelt. Der Team-Builder kombiniert daraus, '
                  'aus der Stärke, dem Mana-Tempo und dem Farbvorteil die besten Teams. Die Gewinnchance gegen ein '
                  'Gegnerteam ist eine Schätzung – kein Kampfsimulator.',
              'Every special and passive skill was broken down into effects (e.g. dispel, cleanse, mana slow). '
                  'A counter table knows which effect negates which. The team builder combines this with power, '
                  'mana speed and color advantage into the best teams. The win chance against an enemy team is an '
                  'estimate – not a battle simulator.',
            )),
          ]),
          Abschnitt(tx('Screenshot-Erkennung', 'Screenshot recognition'), icon: Icons.photo_camera, kinder: [
            Text(tx(
              'Von jedem Heldenporträt ist ein Fingerabdruck gespeichert. Die App sucht im Screenshot das Kartenraster, '
                  'vergleicht jedes Gesicht mit allen Fingerabdrücken und liest Name, Level und Stärke per Texterkennung. '
                  'Alles passiert auf dem Handy, es werden keine Bilder hochgeladen.',
              'A fingerprint of every hero portrait is stored. The app finds the card grid in the screenshot, '
                  'compares every face with all fingerprints and reads name, level and power with text recognition. '
                  'Everything runs on the phone, no images are uploaded.',
            )),
          ]),
        ],
      ),
    );
  }
}
