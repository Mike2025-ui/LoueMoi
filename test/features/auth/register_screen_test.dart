import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('registration form displays all required input fields',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Prenoms'), findsOneWidget);
    expect(find.text('Numéro de téléphone'), findsOneWidget);
    expect(find.text('Numéro WhatsApp (optionnel)'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Confirmer mot de passe'), findsOneWidget);
    expect(find.text('Inscription'), findsWidgets);
  });

  testWidgets('shows a mismatch error when passwords differ', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    // Laisse la restauration de session (AuthController) se résoudre avant
    // d'interagir : le bouton affiche un spinner tant qu'elle est en cours.
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0), 'Kouassi');
    await tester.enterText(find.byType(TextFormField).at(1), 'Jean');
    await tester.enterText(find.byType(TextFormField).at(2), '0700000000');
    await tester.enterText(find.byType(TextFormField).at(3), '0700000000');
    await tester.enterText(find.byType(TextFormField).at(4), 'secret1');
    await tester.enterText(find.byType(TextFormField).at(5), 'different');

    // Le sélecteur de type de compte allonge le formulaire : le bouton peut
    // être hors du viewport de test tant qu'on ne l'a pas fait défiler.
    await tester.ensureVisible(find.text('Inscription').last);
    await tester.tap(find.text('Inscription').last);
    await tester.pump();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });

  testWidgets('has no inline activation notice or WhatsApp button in registration form',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pump();

    // Client par défaut : aucun bandeau ni bouton WhatsApp
    expect(find.text('Activation requise par l’administration'), findsNothing);
    expect(find.text('Nous contacter sur WhatsApp'), findsNothing);
    expect(find.text('Numéro WhatsApp (optionnel)'), findsOneWidget);
  });
}
