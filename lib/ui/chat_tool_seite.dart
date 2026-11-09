// E&P Team-Analyzer – Chat-Tool: Texte mit Farben und Emotes schreiben, Vorschau, speichern, kopieren
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../daten/chat_texte.dart';
import '../daten/sprache.dart';

String _datum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Future<void> _kopieren(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tx('Kopiert – jetzt im Spiel einfügen.', 'Copied – now paste it in the game.')),
    ));
  }
}

/// Vorschau so ähnlich wie im Spiel-Chat (dunkler Hintergrund, Farben, Emotes)
class ChatVorschau extends StatelessWidget {
  final String text;
  final int? maxZeilen;
  const ChatVorschau(this.text, {super.key, this.maxZeilen});

  @override
  Widget build(BuildContext context) {
    final teile = chatParsen(text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2838),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A5068)),
      ),
      child: Text.rich(
        TextSpan(children: [
          for (final t in teile)
            TextSpan(
              text: t.text,
              style: TextStyle(
                color: t.unbekannt ? Colors.grey : Color(t.farbe),
                fontSize: 14 * t.groesse,
                fontWeight: FontWeight.w600,
                height: 1.35,
                decoration: t.unbekannt ? TextDecoration.underline : null,
                decorationStyle: TextDecorationStyle.dotted,
                shadows: const [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))],
              ),
            ),
        ]),
        maxLines: maxZeilen,
        overflow: maxZeilen == null ? null : TextOverflow.ellipsis,
      ),
    );
  }
}

class ChatToolSeite extends StatefulWidget {
  const ChatToolSeite({super.key});

  @override
  State<ChatToolSeite> createState() => _ChatToolSeiteState();
}

class _ChatToolSeiteState extends State<ChatToolSeite> {
  final _texte = ChatTexte.instanz;

  @override
  void initState() {
    super.initState();
    _texte.laden();
  }

  void _oeffnen(ChatText? t) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _ChatEditor(start: t)),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tx('Chat-Tool', 'Chat tool'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _oeffnen(null),
        icon: const Icon(Icons.add),
        label: Text(tx('Neuer Text', 'New text')),
      ),
      body: ListenableBuilder(
        listenable: _texte,
        builder: (context, _) {
          final liste = _texte.liste;
          return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
            Text(
              tx('Schreib Allianz-Nachricht, Rekrutierung oder Chat-Texte mit Farben und Emotes, sieh sofort, wie es im Spiel aussieht, speichere sie und kopiere sie mit einem Tipp.',
                  'Write alliance messages, recruiting or chat texts with colors and emotes, see how it looks in the game, save them and copy with one tap.'),
              style: t.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!_texte.geladen) const Center(child: CircularProgressIndicator()),
            for (final c in liste)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _oeffnen(c),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(c.titel.isEmpty ? tx('Ohne Titel', 'Untitled') : c.titel, style: t.textTheme.titleMedium)),
                        IconButton(
                          tooltip: tx('Kopieren', 'Copy'),
                          icon: const Icon(Icons.copy),
                          onPressed: () => _kopieren(context, c.text),
                        ),
                      ]),
                      Text('${tx('Geändert', 'Changed')} ${_datum(c.geaendert)} · ${c.text.length} ${tx('Zeichen', 'chars')}',
                          style: t.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      ChatVorschau(c.text, maxZeilen: 6),
                    ]),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _ChatEditor extends StatefulWidget {
  final ChatText? start;
  const _ChatEditor({this.start});

  @override
  State<_ChatEditor> createState() => _ChatEditorState();
}

class _ChatEditorState extends State<_ChatEditor> {
  late final TextEditingController _titel = TextEditingController(text: widget.start?.titel ?? '');
  late final TextEditingController _text = TextEditingController(text: widget.start?.text ?? '');
  late final String _id = widget.start?.id ?? ChatTexte.neueId();
  late String _gespeichert = '${widget.start?.titel ?? ''}|${widget.start?.text ?? ''}';

  bool get _geaendert => '${_titel.text}|${_text.text}' != _gespeichert;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _titel.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titel.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Text an der Cursor-Position einfügen
  void _einfuegen(String s) {
    final sel = _text.selection;
    final alt = _text.text;
    final start = sel.isValid ? sel.start : alt.length;
    final ende = sel.isValid ? sel.end : alt.length;
    final neu = alt.replaceRange(start, ende, s);
    _text.value = TextEditingValue(text: neu, selection: TextSelection.collapsed(offset: start + s.length));
  }

  Future<void> _speichern() async {
    final c = ChatText(id: _id, titel: _titel.text.trim(), text: _text.text);
    await ChatTexte.instanz.speichern(c);
    setState(() => _gespeichert = '${_titel.text}|${_text.text}');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('Gespeichert', 'Saved'))));
    }
  }

  Future<void> _farbeEigene() async {
    final feld = TextEditingController();
    final hex = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('Eigene Farbe', 'Custom color')),
        content: StatefulBuilder(
          builder: (ctx, setD) {
            final ok = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(feld.text);
            return Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: feld,
                autofocus: true,
                maxLength: 6,
                decoration: const InputDecoration(prefixText: '#', hintText: 'FF8800', border: OutlineInputBorder()),
                onChanged: (_) => setD(() {}),
              ),
              Container(
                height: 36,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ok ? Color(0xFF000000 | int.parse(feld.text, radix: 16)) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ]);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('Abbrechen', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, feld.text), child: Text(tx('Einfügen', 'Insert'))),
        ],
      ),
    );
    if (hex != null && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) _einfuegen('[#${hex.toUpperCase()}]');
  }

  Future<void> _emotes() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
          Text(tx('Emote antippen = einfügen', 'Tap emote = insert'), style: Theme.of(ctx).textTheme.bodySmall),
          for (final g in emoteGruppen.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(g.key, style: Theme.of(ctx).textTheme.titleSmall),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in g.value)
                InkWell(
                  onTap: () => Navigator.pop(ctx, e),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 74,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(ctx).dividerColor),
                    ),
                    child: Column(children: [
                      Text(chatEmotes[e]!, style: const TextStyle(fontSize: 22)),
                      Text(':$e:', style: const TextStyle(fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
    if (name != null) _einfuegen(':$name:');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final gross = emotesMitGrossbuchstaben(_text.text);
    final unbekannt = unbekannteEmotes(_text.text);
    return PopScope(
      canPop: !_geaendert,
      onPopInvokedWithResult: (weg, _) async {
        if (weg) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tx('Nicht gespeichert', 'Not saved')),
            content: Text(tx('Änderungen verwerfen?', 'Discard changes?')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx('Zurück', 'Back'))),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tx('Verwerfen', 'Discard'))),
            ],
          ),
        );
        if (ok == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.start == null ? tx('Neuer Text', 'New text') : tx('Text bearbeiten', 'Edit text')),
          actions: [
            if (widget.start != null)
              IconButton(
                tooltip: tx('Als Kopie speichern', 'Save as copy'),
                icon: const Icon(Icons.control_point_duplicate),
                onPressed: () async {
                  final c = ChatText(id: ChatTexte.neueId(), titel: '${_titel.text} (Kopie)', text: _text.text);
                  await ChatTexte.instanz.speichern(c);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tx('Kopie gespeichert', 'Copy saved'))));
                  }
                },
              ),
            if (widget.start != null)
              IconButton(
                tooltip: tx('Löschen', 'Delete'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tx('Text löschen?', 'Delete text?')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx('Nein', 'No'))),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tx('Löschen', 'Delete'))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ChatTexte.instanz.loeschen(_id);
                    setState(() => _gespeichert = '${_titel.text}|${_text.text}');
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            IconButton(
              tooltip: tx('Speichern', 'Save'),
              icon: Icon(Icons.save, color: _geaendert ? t.colorScheme.primary : null),
              onPressed: _speichern,
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          TextField(
            controller: _titel,
            decoration: InputDecoration(
              labelText: tx('Titel (nur für dich, z. B. „Allianz-Nachricht Krieg“)', 'Title (just for you)'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),

          // ---------- Werkzeugleiste ----------
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final f in chatFarben)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _einfuegen('[#$f]'),
                    customBorder: const CircleBorder(),
                    child: Tooltip(
                      message: '#$f',
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.grey.shade700,
                        child: CircleAvatar(radius: 15, backgroundColor: Color(0xFF000000 | int.parse(f, radix: 16))),
                      ),
                    ),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.palette, size: 18),
                label: Text(tx('Eigene', 'Custom')),
                onPressed: _farbeEigene,
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            ActionChip(avatar: const Text('😊'), label: Text(tx('Emotes', 'Emotes')), onPressed: _emotes),
            ActionChip(label: Text(tx('Groß [%150]', 'Big [%150]')), onPressed: () => _einfuegen('[%150]')),
            ActionChip(label: Text(tx('Normal [%100]', 'Normal [%100]')), onPressed: () => _einfuegen('[%100]')),
            ActionChip(label: const Text('•'), onPressed: () => _einfuegen('• ')),
            ActionChip(label: const Text('✔'), onPressed: () => _einfuegen('✔ ')),
          ]),
          const SizedBox(height: 8),

          // ---------- Text ----------
          TextField(
            controller: _text,
            minLines: 8,
            maxLines: 18,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: tx('[#6BF9FF]:star: Hallo Allianz :star:', '[#6BF9FF]:star: Hello alliance :star:'),
              helperText: tx('${_text.text.length} Zeichen · Farbe gilt bis zur nächsten Farbe', '${_text.text.length} chars · a color lasts until the next one'),
            ),
          ),
          if (gross.isNotEmpty || unbekannt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (unbekannt.isNotEmpty)
                  Text(
                    tx('Unbekannte Emotes (im Spiel evtl. nur Text): ${unbekannt.toSet().join(' ')}',
                        'Unknown emotes (may show as plain text in game): ${unbekannt.toSet().join(' ')}'),
                    style: t.textTheme.bodySmall?.copyWith(color: Colors.orange),
                  ),
                if (gross.isNotEmpty)
                  Row(children: [
                    Expanded(
                      child: Text(
                        tx('Emotes mit Großbuchstaben: ${gross.toSet().join(' ')} – sicherer ist klein geschrieben.',
                            'Emotes with capitals: ${gross.toSet().join(' ')} – lowercase is safer.'),
                        style: t.textTheme.bodySmall?.copyWith(color: Colors.orange),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _text.text = emotesKlein(_text.text),
                      child: Text(tx('Klein machen', 'Lowercase')),
                    ),
                  ]),
              ]),
            ),
          const SizedBox(height: 14),

          // ---------- Vorschau ----------
          Text(tx('Vorschau', 'Preview'), style: t.textTheme.titleSmall),
          const SizedBox(height: 6),
          ChatVorschau(_text.text),
          const SizedBox(height: 4),
          Text(
            tx('Die Emotes werden hier mit ähnlichen Symbolen gezeigt – im Spiel sehen sie etwas anders aus.',
                'Emotes are shown with similar symbols here – they look a bit different in the game.'),
            style: t.textTheme.bodySmall?.copyWith(color: t.disabledColor),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _kopieren(context, _text.text),
                icon: const Icon(Icons.copy),
                label: Text(tx('Kopieren', 'Copy')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _speichern,
                icon: const Icon(Icons.save),
                label: Text(tx('Speichern', 'Save')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
