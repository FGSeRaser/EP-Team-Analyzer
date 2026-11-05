// E&P Team-Analyzer – macht die Sammlung überall in der App erreichbar
// Autor: FGSeRaser – https://github.com/FGSeRaser

import 'package:flutter/widgets.dart';

import '../daten/sammlung.dart';

class SammlungScope extends InheritedNotifier<Sammlung> {
  const SammlungScope({super.key, required Sammlung sammlung, required super.child})
      : super(notifier: sammlung);

  /// Mit Neuaufbau, wenn sich die Sammlung ändert
  static Sammlung of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SammlungScope>()!.notifier!;

  /// Ohne Neuaufbau (z. B. in Button-Callbacks)
  static Sammlung lesen(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SammlungScope>()!.notifier!;
}
