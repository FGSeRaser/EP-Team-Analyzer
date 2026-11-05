// E&P Team-Analyzer – gemeinsame Bausteine
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/material.dart';

import '../daten/datenbank.dart';

const Map<String, Color> elementFarben = {
  'rot': Color(0xFFE53935),
  'blau': Color(0xFF1E88E5),
  'gruen': Color(0xFF43A047),
  'gelb': Color(0xFFFDD835),
  'lila': Color(0xFF8E24AA),
};

const Map<String, String> elementNamen = {
  'rot': 'Feuer',
  'blau': 'Eis',
  'gruen': 'Natur',
  'gelb': 'Heilig',
  'lila': 'Finster',
};

const Map<String, String> gruppenNamen = {
  'angriff': 'Angriff',
  'schaden': 'Schaden über Zeit',
  'schwaechung': 'Schwächungen',
  'kontrolle': 'Kontrolle & Bannen',
  'mana': 'Mana',
  'heilung': 'Heilung',
  'schutz': 'Schutz',
  'reinigung': 'Reinigen & Leiden-Abwehr',
  'beschwoerung': 'Beschwörung',
  'sonstiges': 'Sonstiges',
};

const Map<String, IconData> gruppenIcons = {
  'angriff': Icons.flash_on,
  'schaden': Icons.local_fire_department,
  'schwaechung': Icons.trending_down,
  'kontrolle': Icons.block,
  'mana': Icons.water_drop,
  'heilung': Icons.favorite,
  'schutz': Icons.shield,
  'reinigung': Icons.auto_fix_high,
  'beschwoerung': Icons.pets,
  'sonstiges': Icons.more_horiz,
};

Color elementFarbe(String e) => elementFarben[e] ?? Colors.grey;

/// Rundes Heldenbild mit Elementrahmen; lädt das Bild von HeroPlan
class HeldBild extends StatelessWidget {
  final Held held;
  final double groesse;
  const HeldBild(this.held, {super.key, this.groesse = 48});

  @override
  Widget build(BuildContext context) {
    final farbe = elementFarbe(held.element);
    return Container(
      width: groesse,
      height: groesse,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(groesse * 0.18),
        border: Border.all(color: farbe, width: 2),
        color: farbe.withAlpha(40),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        held.bildUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            held.name.isEmpty ? '?' : held.name.substring(0, 1),
            style: TextStyle(fontSize: groesse * 0.45, fontWeight: FontWeight.bold, color: farbe),
          ),
        ),
      ),
    );
  }
}

class Sterne extends StatelessWidget {
  final int anzahl;
  final double groesse;
  const Sterne(this.anzahl, {super.key, this.groesse = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        anzahl,
        (_) => Icon(Icons.star, size: groesse, color: const Color(0xFFFFC107)),
      ),
    );
  }
}

class EffektChip extends StatelessWidget {
  final String text;
  final String? gruppe;
  final Color? farbe;
  final VoidCallback? onTap;
  const EffektChip(this.text, {super.key, this.gruppe, this.farbe, this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = farbe ?? Theme.of(context).colorScheme.primary;
    return ActionChip(
      avatar: gruppe == null ? null : Icon(gruppenIcons[gruppe] ?? Icons.label, size: 16, color: f),
      label: Text(text),
      onPressed: onTap ?? () {},
      side: BorderSide(color: f.withAlpha(120)),
      backgroundColor: f.withAlpha(25),
      visualDensity: VisualDensity.compact,
    );
  }
}

class Abschnitt extends StatelessWidget {
  final String titel;
  final IconData? icon;
  final List<Widget> kinder;
  const Abschnitt(this.titel, {super.key, this.icon, required this.kinder});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) Icon(icon, size: 20, color: t.colorScheme.primary),
              if (icon != null) const SizedBox(width: 8),
              Expanded(child: Text(titel, style: t.textTheme.titleMedium)),
            ]),
            const SizedBox(height: 10),
            ...kinder,
          ],
        ),
      ),
    );
  }
}

/// Zeile in Heldenlisten
class HeldKachel extends StatelessWidget {
  final Held held;
  final VoidCallback onTap;
  final Widget? trailing;
  const HeldKachel(this.held, {super.key, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: HeldBild(held),
      title: Row(children: [
        Flexible(child: Text(held.anzeigeName, overflow: TextOverflow.ellipsis)),
        if (held.kommend)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('bald', style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.tertiary)),
          ),
      ]),
      subtitle: Row(children: [
        Sterne(held.sterne, groesse: 12),
        const SizedBox(width: 6),
        Flexible(
          child: Text('${held.klasse} · ${held.tempo}',
              overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
        ),
      ]),
      trailing: trailing ??
          Text('${held.kraft}', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
    );
  }
}
