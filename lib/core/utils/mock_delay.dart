import 'package:flutter/widgets.dart';

/// Délais simulés pour les repositories mock (mode démo).
/// En environnement de test widget/unitaire Flutter, le délai est sauté
/// pour que les tests s'exécutent immédiatement sans laisser de timer
/// en suspens (`!timersPending`).
bool get isFlutterTestEnvironment {
  try {
    final binding = WidgetsBinding.instance;
    if (binding != null && binding.runtimeType.toString().contains('Test')) {
      return true;
    }
  } catch (_) {}
  return false;
}

Future<void> mockDelay([int milliseconds = 300]) async {
  if (!isFlutterTestEnvironment) {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }
}

