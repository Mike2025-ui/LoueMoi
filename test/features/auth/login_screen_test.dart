import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('shows validation errors when submitting an empty form', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    // Laisse la restauration de session (AuthController) se résoudre avant
    // d'interagir : le bouton affiche un spinner tant qu'elle est en cours.
    await tester.pump();

    await tester.tap(find.text('Connexion'));
    await tester.pump();

    expect(find.text('Le numéro de téléphone est requis'), findsOneWidget);
    expect(find.text('Le mot de passe est requis'), findsOneWidget);
  });

  testWidgets('renders the LoueMoi branding and register link', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('LoueMoi'), findsOneWidget);
    expect(find.text('S’inscrire'), findsOneWidget);
  });
}
