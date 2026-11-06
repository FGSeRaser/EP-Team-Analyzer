// E&P Team-Analyzer
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Schicht 1: Helden-Wissensdatenbank, Effekt-Lexikon, Team-Check
// Schicht 2: eigene Sammlung (Screenshot-Erkennung, Namen eintippen, Auswahl)
// Schicht 3: Truppen, Team-Builder, Gegner-Analyse, Deutsch/Englisch

import 'package:flutter/material.dart';

import 'daten/datenbank.dart';
import 'daten/sammlung.dart';
import 'daten/sprache.dart';
import 'daten/updater.dart';
import 'ui/bereiche.dart';
import 'ui/helden_liste.dart';
import 'ui/info_seite.dart';
import 'ui/news_seite.dart';
import 'ui/sammlung_scope.dart';
import 'ui/sammlung_seite.dart';
import 'ui/update_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final sammlung = Sammlung()..laden();
  Sprache.instanz.laden();
  final db = Datenbank.laden();
  runApp(AnalyzerApp(sammlung: sammlung, db: db));
}

class AnalyzerApp extends StatelessWidget {
  final Sammlung sammlung;
  final Future<Datenbank> db;
  const AnalyzerApp({super.key, required this.sammlung, required this.db});

  @override
  Widget build(BuildContext context) {
    // Bei Sprachwechsel wird die ganze App neu aufgebaut
    return ListenableBuilder(
      listenable: Sprache.instanz,
      builder: (context, _) => SammlungScope(
        sammlung: sammlung,
        child: MaterialApp(
          key: ValueKey(Sprache.en),
          title: 'E&P Team-Analyzer',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFB300)),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFB300),
              brightness: Brightness.dark,
            ),
          ),
          home: Startseite(db: db),
        ),
      ),
    );
  }
}

class Startseite extends StatefulWidget {
  final Future<Datenbank> db;
  const Startseite({super.key, required this.db});

  @override
  State<Startseite> createState() => _StartseiteState();
}

class _StartseiteState extends State<Startseite> {
  static int _letzterTab = 0;
  static bool _updateGeprueft = false;
  late int _tab = _letzterTab;

  @override
  void initState() {
    super.initState();
    // Einmal pro App-Start (höchstens einmal am Tag) auf GitHub nach einer neuen Version schauen
    if (!_updateGeprueft) {
      _updateGeprueft = true;
      Future<void>.delayed(const Duration(seconds: 3), () async {
        final info = await Updater.pruefenWennFaellig();
        if (info != null && mounted) await zeigeUpdate(context, info);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Datenbank>(
      future: widget.db,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${tx('Datenbank konnte nicht geladen werden', 'Database could not be loaded')}:\n${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(tx('Lade Heldenwissen …', 'Loading hero knowledge …')),
              ]),
            ),
          );
        }
        final db = snap.data!;
        final seiten = [
          HeldenListe(db: db),
          SammlungSeite(db: db),
          TeamsBereich(db: db),
          WissenBereich(db: db),
          NewsSeite(db: db),
          InfoSeite(db: db),
        ];
        return Scaffold(
          body: IndexedStack(index: _tab, children: seiten),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              setState(() => _tab = _letzterTab = i);
              if (i == 4) newsGelesen();
            },
            destinations: [
              NavigationDestination(icon: const Icon(Icons.people), label: tx('Helden', 'Heroes')),
              NavigationDestination(icon: const Icon(Icons.inventory_2), label: tx('Meine', 'Mine')),
              NavigationDestination(icon: const Icon(Icons.groups), label: 'Teams'),
              NavigationDestination(icon: const Icon(Icons.school), label: tx('Wissen', 'Knowledge')),
              NavigationDestination(
                icon: ValueListenableBuilder<int>(
                  valueListenable: ungeleseneNews,
                  builder: (_, n, kind) => Badge(isLabelVisible: n > 0, label: Text('$n'), child: kind),
                  child: const Icon(Icons.newspaper),
                ),
                label: 'News',
              ),
              const NavigationDestination(icon: Icon(Icons.info_outline), label: 'Info'),
            ],
          ),
        );
      },
    );
  }
}
