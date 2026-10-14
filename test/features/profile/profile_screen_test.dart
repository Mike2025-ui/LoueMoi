import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louemoi/app/routes.dart';
import 'package:louemoi/features/profile/screens/profile_screen.dart';

/// Régression : la maquette cible ne montre pas d'entrée "Messages" dans le
/// menu Profil (contrairement au code précédent) — retirée. La messagerie
/// elle-même reste intacte : seul cet item de menu disparaît, jamais
/// l'onglet Messages de la bottom navigation ni les routes de conversation.
void main() {
  testWidgets("Profil n'affiche plus d'entrée Messages, mais le reste du menu reste intact",
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsNothing);
    expect(find.text('Propriétés contactées'), findsOneWidget);
    expect(find.text('Informations personnelles'), findsOneWidget);
    expect(find.text('Deconnexion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Supprimer mon compte', () {
    Future<void> pumpProfileWithRouter(WidgetTester tester) {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(
            path: AppRoutes.login,
            builder: (c, s) => const Scaffold(body: Text('login-screen')),
          ),
        ],
      );
      return tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
    }

    testWidgets('le bouton est présent', (tester) async {
      await pumpProfileWithRouter(tester);
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte'), findsOneWidget);
    });

    testWidgets('Annuler sur la confirmation ne déclenche rien', (tester) async {
      await pumpProfileWithRouter(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer mon compte ?'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe'), findsNothing);
      expect(find.text('login-screen'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Après ouverture du dialogue de mot de passe, "Supprimer mon compte"
    // matche à la fois le bouton de l'écran (toujours monté sous le
    // dialogue) et le bouton de confirmation du dialogue — on scope donc
    // systématiquement au dialogue pour lever l'ambiguïté.
    Finder confirmButtonInDialog() => find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Supprimer mon compte'),
        );

    testWidgets('mot de passe vide affiche une erreur et ne déconnecte pas', (tester) async {
      await pumpProfileWithRouter(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await tester.tap(confirmButtonInDialog());
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe requis.'), findsOneWidget);
      expect(find.text('login-screen'), findsNothing);
    });

    testWidgets('mot de passe renseigné désactive le compte et navigue vers Login',
        (tester) async {
      await pumpProfileWithRouter(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supprimer mon compte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'secret123');
      await tester.tap(confirmButtonInDialog());
      await tester.pumpAndSettle();

      expect(find.text('login-screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
