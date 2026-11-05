// E&P Team-Analyzer – Update-Dialog mit Download-Fortschritt
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/sprache.dart';
import '../daten/updater.dart';

Future<void> zeigeUpdate(BuildContext context, UpdateInfo info) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(info: info),
  );
}

/// Auf Knopfdruck prüfen und Ergebnis zeigen
Future<void> updateSuchen(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text(tx('Suche nach Updates …', 'Checking for updates …'))));
  final info = await Updater.pruefen();
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();
  if (info == null) {
    messenger.showSnackBar(SnackBar(
        content: Text(tx('GitHub nicht erreichbar oder noch kein Release vorhanden.',
            'GitHub not reachable or no release yet.'))));
  } else if (!info.neuer) {
    messenger.showSnackBar(SnackBar(
        content: Text(tx('Du hast die neueste Version (Build ${info.eigenerBuild}).',
            'You have the latest version (build ${info.eigenerBuild}).'))));
  } else {
    await zeigeUpdate(context, info);
  }
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _fortschritt;
  String? _fehler;
  bool _fertig = false;

  Future<void> _los() async {
    setState(() {
      _fortschritt = 0;
      _fehler = null;
    });
    try {
      final apk = await Updater.herunterladen(widget.info, (p) {
        if (mounted) setState(() => _fortschritt = p);
      });
      if (!mounted) return;
      setState(() => _fertig = true);
      final problem = await Updater.installieren(apk);
      if (!mounted) return;
      if (problem != null) {
        setState(() => _fehler = tx('Installer konnte nicht geöffnet werden: $problem',
            'Could not open the installer: $problem'));
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fehler = tx('Download fehlgeschlagen: $e', 'Download failed: $e');
          _fortschritt = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final i = widget.info;
    final mb = i.groesse > 0 ? ' · ${(i.groesse / 1024 / 1024).toStringAsFixed(1)} MB' : '';
    final laeuft = _fortschritt != null && _fehler == null;
    return AlertDialog(
      icon: const Icon(Icons.system_update, size: 36),
      title: Text(tx('Neue Version verfügbar', 'New version available')),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${i.titel}$mb', style: t.textTheme.titleSmall),
          Text(tx('Installiert: ${i.eigeneVersion} (Build ${i.eigenerBuild})',
              'Installed: ${i.eigeneVersion} (build ${i.eigenerBuild})'),
              style: t.textTheme.bodySmall),
          if (i.notizen.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(i.notizen.trim(), style: t.textTheme.bodySmall),
          ],
          if (laeuft) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _fertig ? null : _fortschritt),
            const SizedBox(height: 6),
            Text(_fertig
                ? tx('Installation wird geöffnet – dort auf „Installieren“ tippen.',
                    'Opening the installer – tap "Install" there.')
                : tx('Lade herunter … ${((_fortschritt ?? 0) * 100).round()} %',
                    'Downloading … ${((_fortschritt ?? 0) * 100).round()}%')),
          ],
          if (_fehler != null) ...[
            const SizedBox(height: 12),
            Text(_fehler!, style: TextStyle(color: t.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          Text(
            tx('Deine Sammlung bleibt erhalten. Beim ersten Mal fragt Android, ob die App Updates installieren darf – bitte erlauben.\n'
                    'Meldet Android „App nicht installiert“: unter Meine → ⋮ → „Sicherung kopieren“ sichern, alte App deinstallieren, neue installieren und die Sicherung wieder einfügen.',
                'Your collection is kept. The first time Android asks whether the app may install updates – please allow it.\n'
                    'If Android says "App not installed": back up via Mine → ⋮ → "Copy backup", uninstall the old app, install the new one and paste the backup.'),
            style: t.textTheme.bodySmall,
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: laeuft && !_fertig ? null : () => Navigator.pop(context),
          child: Text(tx('Später', 'Later')),
        ),
        FilledButton.icon(
          onPressed: laeuft ? null : _los,
          icon: const Icon(Icons.download),
          label: Text(_fehler != null ? tx('Nochmal', 'Retry') : tx('Jetzt aktualisieren', 'Update now')),
        ),
      ],
    );
  }
}
