// E&P Team-Analyzer – Titan: Farbe, Sterne und Besonderheiten
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'sprache.dart';

/// Besonderheiten, die ein Titan haben kann. Der Nutzer kreuzt an, was er im Spiel sieht.
class TitanEigenschaft {
  final String key, de, en, erklDe, erklEn;
  const TitanEigenschaft(this.key, this.de, this.en, this.erklDe, this.erklEn);
  String get name => tx(de, en);
  String get erklaerung => tx(erklDe, erklEn);
}

const List<TitanEigenschaft> titanEigenschaften = [
  TitanEigenschaft('reflekt', 'Reflektiert Schaden', 'Reflects damage',
      'Ein Teil des Schadens kommt zurück – Heilung und Schutz werden wichtiger.',
      'Part of the damage comes back – healing and protection matter more.'),
  TitanEigenschaft('bonus', 'Farb-Bonus', 'Color bonus',
      'Helden einer bestimmten Farbe machen mehr Schaden.', 'Heroes of one color deal more damage.'),
  TitanEigenschaft('hart', 'Harter Gegenangriff', 'Hard counter-attack',
      'Der Titan schlägt stark zurück – Heilung und Schutz einplanen.', 'The titan hits back hard – bring healing and protection.'),
  TitanEigenschaft('bannt', 'Entfernt eure Buffs', 'Removes your buffs',
      '„Angriff hoch“ hält nicht lange – „Verteidigung runter“ auf den Titan ist besser.',
      '"Attack up" won\'t last – "defense down" on the titan is better.'),
  TitanEigenschaft('reinigt', 'Entfernt Debuffs / immun', 'Removes debuffs / immune',
      '„Verteidigung runter“ hält nicht – eigene Buffs (Angriff/Krit hoch) sind besser.',
      '"Defense down" won\'t stick – your own buffs (attack/crit up) are better.'),
];

class TitanInfo {
  String farbe; // rot, blau, gruen, gelb, lila
  int sterne; // 1..14 (+)
  bool selten; // seltener / mythischer Titan
  Set<String> eigenschaften;
  String? bonusFarbe;

  TitanInfo({this.farbe = 'rot', this.sterne = 10, this.selten = false, Set<String>? eigenschaften, this.bonusFarbe})
      : eigenschaften = eigenschaften ?? <String>{};

  bool hat(String k) => eigenschaften.contains(k);

  TitanInfo kopie() =>
      TitanInfo(farbe: farbe, sterne: sterne, selten: selten, eigenschaften: {...eigenschaften}, bonusFarbe: bonusFarbe);
}
