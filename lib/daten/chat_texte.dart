// E&P Team-Analyzer – Chat-Tool: gespeicherte Allianz-/Rekrutierungstexte, Farben, Emotes
// Autor: FGSeRaser – https://github.com/FGSeRaser
//
// Format im Spiel:
//   [#RRGGBB]  ab hier diese Textfarbe (gilt bis zur nächsten Farbe, auch über Zeilen)
//   [%150]     ab hier 150 % Schriftgröße
//   :name:     Emote (z. B. :swords:, :heartblue:)

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Emotes aus dem Spiel -> ähnliches Unicode-Emoji für die Vorschau
const Map<String, String> chatEmotes = {
  'smile': '😊', 'grin': '😁', 'lol': '😆', 'rofl': '🤣', 'sad': '🙁', 'crying': '😢',
  'blush': '☺️', 'rolleyes': '🙄', 'kiss': '😘', 'love': '😍', 'geek': '🤓', 'monocle': '🧐',
  'think': '🤔', 'tongue': '😛', 'cool': '😎', 'angry': '😠', 'evil': '😈', 'horror': '😱',
  'alien': '👽', 'skull': '💀', 'ghost': '👻', 'richard': '🧔', 'hankey': '💩',
  'bunny': '🐰', 'cat': '🐱', 'catgrey': '🐈', 'dog': '🐶', 'fox': '🦊',
  'butterfly': '🦋', 'butterflyblue': '🦋', 'flower': '🌸', 'sunflower': '🌻', 'palmtree': '🌴',
  'heart': '❤️', 'heartblue': '💙', 'heartgreen': '💚', 'heartyellow': '💛', 'heartpurple': '💜',
  'mage': '🧙', 'magered': '🧙‍♂️', 'staff': '🪄',
  'pizza': '🍕', 'cake': '🎂', 'donut': '🍩', 'coffee': '☕', 'ham': '🍖',
  'splash': '💦', 'teardrop': '💧', 'fire': '🔥', 'lightning': '⚡', 'star': '⭐',
  'sword': '🗡️', 'swords': '⚔️', 'axe': '🪓', 'axes': '🪓', 'hammer': '🔨', 'helmet': '🪖',
  'thumbsup': '👍', 'thumbsdown': '👎', 'flex': '💪',
  'elementfire': '🔴', 'elementice': '🔵', 'elementnature': '🟢', 'elementholy': '🟡', 'elementdark': '🟣',
};

/// Gruppen für die Emote-Auswahl
const Map<String, List<String>> emoteGruppen = {
  'Gesichter': ['smile', 'grin', 'lol', 'rofl', 'cool', 'love', 'kiss', 'blush', 'think', 'geek', 'monocle', 'tongue',
    'rolleyes', 'sad', 'crying', 'angry', 'evil', 'horror'],
  'Kampf': ['swords', 'sword', 'axes', 'axe', 'hammer', 'helmet', 'fire', 'lightning', 'star', 'flex', 'thumbsup', 'thumbsdown'],
  'Elemente': ['elementfire', 'elementice', 'elementnature', 'elementholy', 'elementdark'],
  'Herzen': ['heart', 'heartblue', 'heartgreen', 'heartyellow', 'heartpurple'],
  'Tiere & Natur': ['cat', 'catgrey', 'dog', 'fox', 'bunny', 'butterfly', 'butterflyblue', 'flower', 'sunflower', 'palmtree',
    'splash', 'teardrop'],
  'Sonstiges': ['mage', 'magered', 'staff', 'pizza', 'cake', 'donut', 'coffee', 'ham', 'alien', 'skull', 'ghost', 'richard', 'hankey'],
};

/// Beliebte Farben (inkl. der aus euren Texten)
const List<String> chatFarben = [
  'FFFFFF', '6BF9FF', 'FFD54F', '00FF00', 'FF3333', 'A5D6A7',
  'FF9800', 'E040FB', '2196F3', 'FFEB3B', 'F48FB1', '9E9E9E',
];

/// Ein Stück Text mit Farbe/Größe – oder ein Emote
class ChatTeil {
  final String text;
  final int farbe; // 0xAARRGGBB
  final double groesse; // 1.0 = normal
  final String? emote; // Emote-Name, wenn es eins ist
  final bool unbekannt; // :xyz: ohne bekanntes Emote
  const ChatTeil(this.text, this.farbe, this.groesse, {this.emote, this.unbekannt = false});
}

final _token = RegExp(r'\[#([0-9a-fA-F]{6})\]|\[%(\d{2,3})\]|:([A-Za-z]+):');

/// Text in Teile zerlegen (für die Vorschau)
List<ChatTeil> chatParsen(String text, {int standardFarbe = 0xFFFFFFFF}) {
  final teile = <ChatTeil>[];
  var farbe = standardFarbe;
  var groesse = 1.0;
  var pos = 0;
  for (final m in _token.allMatches(text)) {
    if (m.start > pos) teile.add(ChatTeil(text.substring(pos, m.start), farbe, groesse));
    if (m.group(1) != null) {
      farbe = 0xFF000000 | int.parse(m.group(1)!, radix: 16);
    } else if (m.group(2) != null) {
      groesse = (int.parse(m.group(2)!) / 100).clamp(0.5, 3.0);
    } else {
      final name = m.group(3)!.toLowerCase();
      final e = chatEmotes[name];
      teile.add(e != null
          ? ChatTeil(e, farbe, groesse, emote: name)
          : ChatTeil(m.group(0)!, farbe, groesse, unbekannt: true));
    }
    pos = m.end;
  }
  if (pos < text.length) teile.add(ChatTeil(text.substring(pos), farbe, groesse));
  return teile;
}

/// Emotes, die nicht klein geschrieben sind (z. B. :FLEX:, :Swords:)
List<String> emotesMitGrossbuchstaben(String text) => [
      for (final m in RegExp(r':([A-Za-z]+):').allMatches(text))
        if (m.group(1) != m.group(1)!.toLowerCase() && chatEmotes.containsKey(m.group(1)!.toLowerCase())) m.group(0)!,
    ];

/// Alle Emotes klein schreiben
String emotesKlein(String text) => text.replaceAllMapped(RegExp(r':([A-Za-z]+):'), (m) {
      final k = m.group(1)!.toLowerCase();
      return chatEmotes.containsKey(k) ? ':$k:' : m.group(0)!;
    });

/// Unbekannte Emote-Codes im Text
List<String> unbekannteEmotes(String text) => [
      for (final m in RegExp(r':([A-Za-z]+):').allMatches(text))
        if (!chatEmotes.containsKey(m.group(1)!.toLowerCase())) m.group(0)!,
    ];

class ChatText {
  final String id;
  String titel;
  String text;
  DateTime geaendert;
  ChatText({required this.id, required this.titel, required this.text, DateTime? geaendert})
      : geaendert = geaendert ?? DateTime.now();

  Map<String, dynamic> toJson() => {'id': id, 'titel': titel, 'text': text, 'geaendert': geaendert.toIso8601String()};
  factory ChatText.ausJson(Map<String, dynamic> j) => ChatText(
        id: j['id'] as String,
        titel: (j['titel'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        geaendert: DateTime.tryParse((j['geaendert'] ?? '') as String),
      );
}

/// Gespeicherte Texte (lokal auf dem Handy)
class ChatTexte extends ChangeNotifier {
  static final ChatTexte instanz = ChatTexte._();
  ChatTexte._();

  static const _key = 'chat_texte';
  final List<ChatText> _liste = [];
  bool _geladen = false;

  List<ChatText> get liste => List.unmodifiable(_liste..sort((a, b) => b.geaendert.compareTo(a.geaendert)));
  bool get geladen => _geladen;

  Future<void> laden() async {
    if (_geladen) return;
    final p = await SharedPreferences.getInstance();
    final roh = p.getString(_key);
    _liste.clear();
    if (roh == null) {
      _liste.addAll(_vorlagen());
      await _speichern();
    } else {
      for (final x in jsonDecode(roh) as List) {
        _liste.add(ChatText.ausJson(x as Map<String, dynamic>));
      }
    }
    _geladen = true;
    notifyListeners();
  }

  Future<void> _speichern() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode([for (final t in _liste) t.toJson()]));
  }

  Future<void> speichern(ChatText t) async {
    t.geaendert = DateTime.now();
    final i = _liste.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      _liste[i] = t;
    } else {
      _liste.add(t);
    }
    await _speichern();
    notifyListeners();
  }

  Future<void> loeschen(String id) async {
    _liste.removeWhere((x) => x.id == id);
    await _speichern();
    notifyListeners();
  }

  static String neueId() => DateTime.now().microsecondsSinceEpoch.toString();

  static List<ChatText> _vorlagen() => [
        ChatText(id: 'vorlage_allianz', titel: 'Allianz-Nachricht', text: '''[#6bf9ff]:star: WILLKOMMEN BEI ARTEX :star:

[#FFD54F]:elementice: TITAN:
[#FFFFFF]• Regelmäßig angreifen! :swords:

[#00ff00] :star: EVENTS:
[#FFFFFF]• Blutfest :swords:
• Krieg der Drei Königreiche :sword:
• Maskerade :swords:

[#ff3333]:fire: KRIEG:
[#FFFFFF]• Freie Tankwahl :helmet:
[#FFFFFF]• Haken drin = 6/6 Angriffe Pflicht!
[#FFFFFF]• Modus: Untote Horde :swords:
[#00ff00]• Pause / Abwesenheit = Haken raus! :cool:

[#6bf9ff]:heartblue: Viel Spaß & Guten Loot :flex:'''),
        ChatText(id: 'vorlage_rekrutierung', titel: 'Rekrutierung', text: '''[#6bf9ff]:star: ArTeX sucht Verstärkung! :star:

[#FFFFFF]Wir sind eine entspannte, hilfsbereite & anfängerfreundliche Allianz :smile:
Bei uns zählt Spaß am Spiel – kein Stress, kein Zwang! :thumbsup:

[#A5D6A7]✔ Hilfe & Tipps für Neulinge :star:
✔ Gemeinsam stärker werden :flex:
✔ Aktiv Alliquest & Events spielen :sword:
✔ RL geht immer vor :heartblue:
✔ Wer im Krieg den Haken setzt, nutzt bitte alle 6 Angriffe :swords:

[#FFD54F]Du suchst eine lockere Gemeinschaft?
Dann komm zu ArTeX! :elementice:'''),
      ];
}
