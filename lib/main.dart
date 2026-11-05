// E&P Team-Analyzer
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Schicht 1: Helden-Wissensdatenbank, Effekt-Lexikon, Team-Check
// Schicht 2a: eigene Sammlung (Screenshot-Erkennung, Namen eintippen, Auswahl)

import 'package:flutter/material.dart';

import 'daten/datenbank.dart';
import 'daten/sammlung.dart';
import 'ui/effekte_seite.dart';
import 'ui/helden_liste.dart';
import 'ui/info_seite.dart';
import 'ui/sammlung_scope.dart';
import 'ui/sammlung_seite.dart';
import 'ui/team_check.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final sammlung = Sammlung()..laden();
  runApp(AnalyzerApp(sammlung: sammlung));
}

class AnalyzerApp extends StatelessWidget {
  final Sammlung sammlung;
  const AnalyzerApp({super.key, required this.sammlung});

  @override
  Widget build(BuildContext context) {
    return SammlungScope(
      sammlung: sammlung,
      child: MaterialApp(
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
      home: const Startseite(),
      ),
    );
  }
}

class Startseite extends StatefulWidget {
  const Startseite({super.key});

  @override
  State<Startseite> createState() => _StartseiteState();
}

class _StartseiteState extends State<Startseite> {
  late final Future<Datenbank> _db = Datenbank.laden();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Datenbank>(
      future: _db,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Datenbank konnte nicht geladen werden:\n${snap.error}'),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Lade Heldenwissen …'),
              ]),
            ),
          );
        }
        final db = snap.data!;
        final seiten = [
          HeldenListe(db: db),
          SammlungSeite(db: db),
          TeamCheck(db: db),
          EffekteSeite(db: db),
          InfoSeite(db: db),
        ];
        return Scaffold(
          body: IndexedStack(index: _tab, children: seiten),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.people), label: 'Helden'),
              NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Meine'),
              NavigationDestination(icon: Icon(Icons.groups), label: 'Team'),
              NavigationDestination(icon: Icon(Icons.menu_book), label: 'Effekte'),
              NavigationDestination(icon: Icon(Icons.info_outline), label: 'Info'),
            ],
          ),
        );
      },
    );
  }
}
