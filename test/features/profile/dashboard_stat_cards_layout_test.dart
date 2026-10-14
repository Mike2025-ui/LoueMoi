import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/profile/screens/agent_dashboard_screen.dart';
import 'package:louemoi/features/profile/screens/bailleur_dashboard_screen.dart';

/// Régression pour "BOTTOM OVERFLOWED BY 6.7 PIXELS" reproduit sur téléphone
/// réel sur l'écran Statistiques (AgentDashboardScreen / BailleurDashboardScreen).
/// Cause racine : GridView.count(childAspectRatio: 1.5) imposait une hauteur
/// de cellule calculée, insuffisante pour icône + valeur + libellé avec les
/// métriques de police d'un vrai appareil. Corrigé en remplaçant la grille
/// par des Row de cartes en Expanded (hauteur intrinsèque au contenu,
/// jamais imposée).
Future<void> _pumpAt(WidgetTester tester, Widget screen, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: screen)),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
    testWidgets('AgentDashboardScreen ne déborde pas à ${width}px de large', (tester) async {
      await _pumpAt(tester, const AgentDashboardScreen(), Size(width, 800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('BailleurDashboardScreen ne déborde pas à ${width}px de large', (tester) async {
      await _pumpAt(tester, const BailleurDashboardScreen(), Size(width, 800));
      expect(tester.takeException(), isNull);
    });
  }
}
