// E&P Team-Analyzer – Event-Kalender: was läuft, was kommt, wie lange
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../daten/news.dart';
import '../daten/sprache.dart';

const _wochentageDe = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _wochentageEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _zwei(int v) => v.toString().padLeft(2, '0');

/// "Fr 06.11. 08:00" in Ortszeit
String terminZeit(DateTime utc) {
  final d = utc.toLocal();
  final wt = (Sprache.en ? _wochentageEn : _wochentageDe)[d.weekday - 1];
  return '$wt ${_zwei(d.day)}.${_zwei(d.month)}. ${_zwei(d.hour)}:${_zwei(d.minute)}';
}

/// "2 T 5 Std" / "3 Std 20 Min"
String dauerText(Duration d) {
  if (d.isNegative) return '–';
  final t = d.inDays, h = d.inHours % 24, m = d.inMinutes % 60;
  if (t > 0) return tx('$t T ${h > 0 ? '$h Std' : ''}', '${t}d ${h > 0 ? '${h}h' : ''}').trim();
  if (d.inHours > 0) return tx('${d.inHours} Std ${m > 0 ? '$m Min' : ''}', '${d.inHours}h ${m > 0 ? '${m}m' : ''}').trim();
  return tx('$m Min', '${m}m');
}

IconData eventIcon(String name) {
  final a = eventArt(name).name;
  if (a == tx('Beschwörung', 'Summon')) return Icons.auto_awesome;
  if (a == tx('Allianz-Quest', 'Alliance quest')) return Icons.shield;
  if (a == 'Titan') return Icons.whatshot;
  if (a == tx('Krieg', 'War')) return Icons.sports_kabaddi;
  if (a == tx('Wettbewerb', 'Competition')) return Icons.emoji_events;
  if (a == tx('Turm', 'Tower')) return Icons.apartment;
  return Icons.flag;
}

/// Eine Zeile für einen Termin – mit Fortschritt, wenn er gerade läuft
class TerminZeile extends StatelessWidget {
  final EventTermin termin;
  final DateTime jetzt;
  const TerminZeile(this.termin, this.jetzt, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final e = termin;
    final laeuft = e.laeuft(jetzt);
    final vorbei = !jetzt.isBefore(e.ende);
    final anteil = laeuft ? jetzt.difference(e.start).inMinutes / e.dauer.inMinutes.clamp(1, 1 << 30) : (vorbei ? 1.0 : 0.0);
    final info = laeuft
        ? tx('läuft noch ${dauerText(e.ende.difference(jetzt))} · bis ${terminZeit(e.ende)}',
            '${dauerText(e.ende.difference(jetzt))} left · until ${terminZeit(e.ende)}')
        : vorbei
            ? tx('vorbei · ${terminZeit(e.start)} – ${terminZeit(e.ende)}', 'ended · ${terminZeit(e.start)} – ${terminZeit(e.ende)}')
            : tx('startet in ${dauerText(e.start.difference(jetzt))} · ${terminZeit(e.start)} · dauert ${dauerText(e.dauer)}',
                'starts in ${dauerText(e.start.difference(jetzt))} · ${terminZeit(e.start)} · lasts ${dauerText(e.dauer)}');
    return Opacity(
      opacity: vorbei ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: laeuft ? Colors.green.withValues(alpha: 0.2) : t.colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(eventIcon(e.name), size: 18, color: laeuft ? Colors.green : t.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e.nameL} ${e.symbol}'.trim(), style: t.textTheme.titleSmall),
              if (e.nameL != e.name) Text(e.name, style: t.textTheme.labelSmall?.copyWith(color: t.disabledColor)),
              Text('${eventArt(e.name).name} · $info', style: t.textTheme.bodySmall),
              if (laeuft) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: anteil.clamp(0.0, 1.0), minHeight: 5),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class KalenderSeite extends StatefulWidget {
  final List<EventTermin> termine;
  final List<String> regeln;
  const KalenderSeite({super.key, required this.termine, required this.regeln});

  @override
  State<KalenderSeite> createState() => _KalenderSeiteState();
}

class _KalenderSeiteState extends State<KalenderSeite> {
  bool _vergangene = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final jetzt = DateTime.now().toUtc();
    final laufend = widget.termine.where((e) => e.laeuft(jetzt)).toList()..sort((a, b) => a.ende.compareTo(b.ende));
    final kommend = widget.termine.where((e) => jetzt.isBefore(e.start)).toList();
    final vorbei = widget.termine.where((e) => !jetzt.isBefore(e.ende)).toList().reversed.toList();

    // Kommende Termine nach Starttag gruppieren
    final tage = <String, List<EventTermin>>{};
    for (final e in kommend) {
      final d = e.start.toLocal();
      final wt = (Sprache.en ? _wochentageEn : _wochentageDe)[d.weekday - 1];
      tage.putIfAbsent('$wt ${_zwei(d.day)}.${_zwei(d.month)}.', () => []).add(e);
    }

    Widget kopf(String text, IconData icon, [Color? farbe]) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(children: [
            Icon(icon, size: 20, color: farbe ?? t.colorScheme.primary),
            const SizedBox(width: 8),
            Text(text, style: t.textTheme.titleMedium),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(tx('Event-Kalender', 'Event calendar'))),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            tx('Alle Zeiten in deiner Ortszeit. Quelle: offizieller „Calendar of Events“ von Empires & Puzzles – Änderungen durch das Spiel sind möglich.',
                'All times in your local time. Source: the official Empires & Puzzles "Calendar of Events" – the game may change it.'),
            style: t.textTheme.bodySmall,
          ),
        ),
        if (widget.termine.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(tx('Noch kein Kalender geladen.', 'No calendar loaded yet.'), textAlign: TextAlign.center),
          ),
        if (laufend.isNotEmpty) ...[
          kopf(tx('Läuft gerade (${laufend.length})', 'Running now (${laufend.length})'), Icons.play_circle, Colors.green),
          for (final e in laufend) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TerminZeile(e, jetzt)),
        ],
        if (tage.isNotEmpty) ...[
          kopf(tx('Demnächst', 'Coming up'), Icons.upcoming),
          for (final tag in tage.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(tag.key, style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
            ),
            for (final e in tag.value) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TerminZeile(e, jetzt)),
          ],
        ],
        if (widget.regeln.isNotEmpty) ...[
          kopf(tx('Wiederkehrend', 'Recurring'), Icons.repeat),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final r in widget.regeln)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $r', style: t.textTheme.bodySmall)),

            ]),
          ),
        ],
        if (vorbei.isNotEmpty) ...[
          kopf(tx('Vorbei (${vorbei.length})', 'Ended (${vorbei.length})'), Icons.history, t.disabledColor),
          if (!_vergangene)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton(
                    onPressed: () => setState(() => _vergangene = true), child: Text(tx('Anzeigen', 'Show'))),
              ),
            )
          else
            for (final e in vorbei.take(30)) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TerminZeile(e, jetzt)),
        ],
        if (widget.termine.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(widget.termine.last.artikel), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(tx('Offiziellen Kalender öffnen', 'Open official calendar')),
            ),
          ),
      ]),
    );
  }
}
