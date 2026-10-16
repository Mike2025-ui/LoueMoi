import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/theme/app_colors.dart';
import 'package:louemoi/features/auth/screens/register_screen.dart';

void main() {
  testWidgets('account type selector defaults to Client and can switch to Bailleur/Agent',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pump();

    Color? pillColor(String label) {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.widgetWithText(InkWell, label),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    expect(find.text('Type de compte'), findsOneWidget);
    // Client sélectionné par défaut, conformément au cahier des charges.
    expect(pillColor('Client'), AppColors.primary);
    expect(pillColor('Bailleur'), AppColors.white);
    expect(pillColor('Agent'), AppColors.white);

    await tester.tap(find.text('Bailleur'));
    await tester.pump();

    expect(pillColor('Client'), AppColors.white);
    expect(pillColor('Bailleur'), AppColors.primary);
    expect(pillColor('Agent'), AppColors.white);

    await tester.tap(find.text('Agent'));
    await tester.pump();

    expect(pillColor('Bailleur'), AppColors.white);
    expect(pillColor('Agent'), AppColors.primary);
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
    await tester.enterText(find.byType(TextFormField).at(3), 'secret1');
    await tester.enterText(find.byType(TextFormField).at(4), 'different');

    // Le sélecteur de type de compte allonge le formulaire : le bouton peut
    // être hors du viewport de test tant qu'on ne l'a pas fait défiler.
    await tester.ensureVisible(find.text('Inscription').last);
    await tester.tap(find.text('Inscription').last);
    await tester.pump();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });

  testWidgets('shows admin activation notice and WhatsApp button only for Bailleur and Agent',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pump();

    // Au départ (Client par défaut) : aucun bandeau ni bouton WhatsApp
    expect(find.text('Activation requise par l’administration'), findsNothing);
    expect(find.text('Nous contacter sur WhatsApp'), findsNothing);

    // Sélection Bailleur : le bandeau et le bouton apparaissent
    await tester.tap(find.text('Bailleur'));
    await tester.pump();
    expect(find.text('Activation requise par l’administration'), findsOneWidget);
    expect(find.text('Nous contacter sur WhatsApp'), findsOneWidget);
    expect(find.textContaining('les comptes Bailleur font l’objet d’une vérification'), findsOneWidget);

    // Sélection Agent : le bandeau s'adapte
    await tester.tap(find.text('Agent'));
    await tester.pump();
    expect(find.text('Activation requise par l’administration'), findsOneWidget);
    expect(find.text('Nous contacter sur WhatsApp'), findsOneWidget);
    expect(find.textContaining('les comptes Agent immobilier font l’objet d’une vérification'), findsOneWidget);

    // Retour sur Client : le bandeau disparaît
    await tester.tap(find.text('Client'));
    await tester.pump();
    expect(find.text('Activation requise par l’administration'), findsNothing);
    expect(find.text('Nous contacter sur WhatsApp'), findsNothing);
  });
}
