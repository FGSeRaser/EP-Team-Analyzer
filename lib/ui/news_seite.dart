// E&P Team-Analyzer – News-Tab: Held des Monats, neue Helden, Balance-Änderungen, offizielle News
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../daten/datenbank.dart';
import '../daten/news.dart';
import '../daten/sprache.dart';
import 'held_analyse_seite.dart';
import 'held_detail.dart';
import 'widgets.dart';

/// Anzahl ungelesener News (für das Abzeichen in der Navigationsleiste)
final ValueNotifier<int> ungeleseneNews = ValueNotifier<int>(0);
DateTime? _neuesteNews;

/// Beim Öffnen des Tabs aufrufen
Future<void> newsGelesen() async {
  final d = _neuesteNews;
  if (d == null) return;
  ungeleseneNews.value = 0;
  await NewsDienst.alsGesehen(d);
}

String _datum(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

class NewsSeite extends StatefulWidget {
  final Datenbank db;
  const NewsSeite({super.key, required this.db});

  @override
  State<NewsSeite> createState() => _NewsSeiteState();
}

class _NewsSeiteState extends State<NewsSeite> {
  NewsStand? _stand;
  DateTime? _gesehen;
  bool _laedt = true;
  String _filter = 'alle';

  Datenbank get db => widget.db;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() => _laedt = true);
    final gesehen = await NewsDienst.gesehenBis();
    final s = await NewsDienst.laden();
    if (!mounted) return;
    if (s.artikel.isNotEmpty) {
      _neuesteNews = s.artikel.first.datum;
      ungeleseneNews.value = s.artikel.where((a) => gesehen == null || a.datum.isAfter(gesehen)).length.clamp(0, 99);
      // Beim allerersten Start nicht alles als neu markieren
      if (gesehen == null) {
        ungeleseneNews.value = 0;
        await NewsDienst.alsGesehen(s.artikel.first.datum);
      }
    }
    setState(() {
      _stand = s;
      _gesehen = gesehen ?? (s.artikel.isEmpty ? null : s.artikel.first.datum);
      _laedt = false;
    });
  }

  void _held(Held h) => Navigator.push(context, MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h)));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final jetzt = DateTime.now();
    final naechster = DateTime(jetzt.year, jetzt.month + 1);
    final danach = DateTime(jetzt.year, jetzt.month + 2);
    final hdmJetzt = heldenDesMonats(db, jetzt.year, jetzt.month);
    final hdmNaechster = heldenDesMonats(db, naechster.year, naechster.month);
    final hdmDanach = heldenDesMonats(db, danach.year, danach.month);
    final neu = neueHelden(db).where((h) => !h.quelle.startsWith('MonthlyHero')).toList();
    final artikel = _stand?.artikel ?? const <NewsArtikel>[];
    final balance = artikel.where((a) => a.balance).take(4).toList();
    final gefiltert = _filter == 'alle' ? artikel : artikel.where((a) => a.arten.contains(_filter)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tx('News', 'News')), actions: [
        IconButton(onPressed: _laedt ? null : _laden, icon: const Icon(Icons.refresh), tooltip: tx('Aktualisieren', 'Refresh')),
      ]),
      body: RefreshIndicator(
        onRefresh: _laden,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // ---------- Held des Monats ----------
            Abschnitt(tx('Held des Monats', 'Hero of the Month'), icon: Icons.workspace_premium, kinder: [
              _hdm(t, tx('Aktuell – ${monatName(jetzt.year, jetzt.month)}', 'Current – ${monatName(jetzt.year, jetzt.month)}'), hdmJetzt),
              const SizedBox(height: 12),
              _hdm(t, tx('Nächster – ${monatName(naechster.year, naechster.month)}', 'Next – ${monatName(naechster.year, naechster.month)}'),
                  hdmNaechster),
              if (hdmDanach.isNotEmpty) ...[
                const SizedBox(height: 12),
                _hdm(t, tx('Danach – ${monatName(danach.year, danach.month)}', 'After that – ${monatName(danach.year, danach.month)}'),
                    hdmDanach),
              ],
            ]),

            // ---------- Neue Helden ----------
            if (neu.isNotEmpty)
              Abschnitt(tx('Neue & kommende Helden', 'New & upcoming heroes'), icon: Icons.fiber_new, kinder: [
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: neu.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final h = neu[i];
                      return InkWell(
                        onTap: () => _held(h),
                        child: SizedBox(
                          width: 72,
                          child: Column(children: [
                            HeldBild(h, groesse: 56),
                            Text(h.nameL, style: t.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(h.kommend ? tx('kommt', 'soon') : _kurzDatum(h.datum),
                                style: t.textTheme.labelSmall?.copyWith(fontSize: 9, color: h.kommend ? Colors.orange : null)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ]),

            // ---------- Balance ----------
            if (balance.isNotEmpty)
              Abschnitt(tx('Balance-Änderungen', 'Balance changes'), icon: Icons.balance, kinder: [
                for (final a in balance) _artikelZeile(t, a),
              ]),

            // ---------- Offizielle News ----------
            Abschnitt(tx('Offizielle News', 'Official news'), icon: Icons.campaign, kinder: [
              if (_laedt && artikel.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              if (_stand?.fehler != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _stand!.ausCache
                        ? tx('Kein Netz – zeige die zuletzt geladenen News.', 'No connection – showing the last loaded news.')
                        : tx('News konnten nicht geladen werden. Zum Aktualisieren nach unten ziehen.',
                            'News could not be loaded. Pull down to refresh.'),
                    style: t.textTheme.bodySmall?.copyWith(color: Colors.orange),
                  ),
                ),
              if (artikel.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in const ['alle', 'balance', 'version', 'kalender', 'event', 'statistik'])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(f == 'alle' ? tx('Alle', 'All') : newsArtName(f)),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ]),
                ),
              const SizedBox(height: 6),
              for (final a in gefiltert.take(30)) _artikelZeile(t, a),
              if (artikel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tx('Quelle: empiresandpuzzles.com/news · wird alle 6 Stunden eingesammelt${_stand!.stand.isEmpty ? '' : ' · Stand ${_stand!.stand.replaceAll('T', ' ').replaceAll('Z', ' UTC')}'}',
                        'Source: empiresandpuzzles.com/news · collected every 6 hours${_stand!.stand.isEmpty ? '' : ' · as of ${_stand!.stand.replaceAll('T', ' ').replaceAll('Z', ' UTC')}'}'),
                    style: t.textTheme.bodySmall?.copyWith(color: t.disabledColor),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  String _kurzDatum(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
  }

  Widget _hdm(ThemeData t, String titel, List<Held> helden) {
    if (helden.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titel, style: t.textTheme.titleSmall),
        Text(tx('Noch nicht bekannt – kommt mit dem nächsten Daten-Update.', 'Not known yet – comes with the next data update.'),
            style: t.textTheme.bodySmall),
      ]);
    }
    final haupt = helden.first;
    final begleiter = helden.skip(1).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titel, style: t.textTheme.titleSmall),
      const SizedBox(height: 6),
      InkWell(
        onTap: () => _held(haupt),
        borderRadius: BorderRadius.circular(10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HeldBild(haupt, groesse: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(haupt.anzeigeName, style: t.textTheme.titleMedium),
              Sterne(haupt.sterne),
              Text('${elementName(haupt.element)} · ${haupt.klasseL} · ${haupt.tempoL}', style: t.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(haupt.spezialNameL, style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
              for (final z in haupt.spezialL.take(4)) Text('• $z', style: t.textTheme.bodySmall, maxLines: 3),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => HeldAnalyseSeite(db: db, start: haupt))),
                  icon: const Icon(Icons.account_tree, size: 16),
                  label: Text(tx('Talente', 'Talents')),
                ),
              ),
            ]),
          ),
        ]),
      ),
      if (begleiter.isNotEmpty) ...[
        Text(tx('Dazu im Paket:', 'Also in the bundle:'), style: t.textTheme.bodySmall),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final h in begleiter)
            InkWell(
              onTap: () => _held(h),
              child: Column(children: [
                HeldBild(h, groesse: 44),
                SizedBox(width: 60, child: Text(h.nameL, style: t.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
              ]),
            ),
        ]),
      ],
    ]);
  }

  Widget _artikelZeile(ThemeData t, NewsArtikel a) {
    final neu = _gesehen != null && a.datum.isAfter(_gesehen!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        switch (a.arten.first) {
          'balance' => Icons.balance,
          'version' => Icons.system_update,
          'kalender' => Icons.calendar_month,
          'statistik' => Icons.bar_chart,
          'event' => Icons.celebration,
          _ => Icons.article,
        },
        color: a.balance ? Colors.orange : t.colorScheme.primary,
      ),
      title: Text(a.titel, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_datum(a.datum)} · ${a.arten.map(newsArtName).join(', ')}'),
      trailing: neu
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
              child: Text(tx('NEU', 'NEW'), style: const TextStyle(color: Colors.white, fontSize: 10)),
            )
          : null,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ArtikelSeite(db: db, artikel: a))),
    );
  }
}

class _ArtikelSeite extends StatelessWidget {
  final Datenbank db;
  final NewsArtikel artikel;
  const _ArtikelSeite({required this.db, required this.artikel});

  Future<void> _oeffnen(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = artikel;
    final helden = erwaehnteHelden(db, a.text);
    return Scaffold(
      appBar: AppBar(title: Text(a.arten.map(newsArtName).join(' · '))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(a.titel, style: t.textTheme.titleLarge),
        Text(_datum(a.datum), style: t.textTheme.bodySmall),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6, children: [
          FilledButton.tonalIcon(
            onPressed: () => _oeffnen(a.url),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(tx('Original öffnen', 'Open original')),
          ),
          if (!Sprache.en)
            OutlinedButton.icon(
              onPressed: () => _oeffnen('https://translate.google.com/translate?sl=en&tl=de&u=${Uri.encodeComponent(a.url)}'),
              icon: const Icon(Icons.translate, size: 18),
              label: const Text('Auf Deutsch lesen'),
            ),
        ]),
        if (helden.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(tx('Erwähnte Helden (${helden.length})', 'Mentioned heroes (${helden.length})'), style: t.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final h in helden)
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeldDetail(db: db, held: h))),
                child: Column(children: [
                  HeldBild(h, groesse: 44),
                  SizedBox(width: 60, child: Text(h.nameL, style: t.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
                ]),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        if (!Sprache.en)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Die offiziellen News gibt es nur auf Englisch.', style: t.textTheme.bodySmall?.copyWith(color: t.disabledColor)),
          ),
        if (a.text.isEmpty)
          Text(tx('Für diesen Artikel liegt kein Text vor – öffne das Original.', 'No text for this article – open the original.'))
        else
          SelectableText(a.text, style: t.textTheme.bodyMedium),
      ]),
    );
  }
}
