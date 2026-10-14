import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/profile/screens/agent_space_screen.dart';

/// Régression pour l'en-tête dupliqué reproduit sur téléphone réel : l'AppBar
/// affichait un AgentCard (avatar + nom + "Agent immobilier") EN PLUS du bloc
/// identique déjà présent dans le corps de l'écran. Corrigé en simplifiant
/// l'AppBar à un simple titre (comme BailleurSpaceScreen).
void main() {
  testWidgets('"Agent immobilier" n\'apparaît qu\'une seule fois', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AgentSpaceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agent immobilier'), findsOneWidget);
    expect(find.text('Espace agent'), findsOneWidget);
  });

  testWidgets('demander la certification affiche une confirmation, sans exception', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AgentSpaceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Certification'), findsOneWidget);
    await tester.tap(find.text('Certification'));
    await tester.pumpAndSettle();

    expect(find.text('Demande de certification envoyée.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
