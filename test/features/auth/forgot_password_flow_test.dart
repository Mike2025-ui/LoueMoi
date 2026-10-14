import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louemoi/app/routes.dart';
import 'package:louemoi/features/auth/screens/forgot_password_screen.dart';
import 'package:louemoi/features/auth/screens/login_screen.dart';
import 'package:louemoi/features/auth/screens/reset_password_screen.dart';

/// "Mot de passe oublié" : Numéro → OTP SMS → Vérification + nouveau mot de
/// passe → Connexion. MockAuthRepository.confirmPasswordReset n'accepte que
/// le code "123456" comme valide (voir auth_repository.dart), ce qui permet
/// de tester les deux chemins (code correct / incorrect) sans dépendre d'un
/// vrai fournisseur SMS.
void main() {
  GoRouter buildRouter() {
    return GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(path: AppRoutes.login, builder: (c, s) => const LoginScreen()),
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (c, s) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: AppRoutes.resetPassword,
          builder: (c, s) => ResetPasswordScreen(
            phone: Uri.decodeComponent(s.pathParameters['phone']!),
          ),
        ),
      ],
    );
  }

  testWidgets('le lien "Mot de passe oublié ?" ouvre le bon écran', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: buildRouter())),
    );
    await tester.pump();

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });

  testWidgets('demander un code sans numéro affiche une erreur de validation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ForgotPasswordScreen())),
    );

    await tester.tap(find.text('Envoyer le code'));
    await tester.pump();

    expect(find.text('Le numéro de téléphone est requis'), findsOneWidget);
  });

  testWidgets('flux complet réussi : téléphone → code correct → retour login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: buildRouter())),
    );
    await tester.pump();

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '+2250700000000');
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordScreen), findsOneWidget);
    expect(find.textContaining('+2250700000000'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456'); // code
    await tester.enterText(fields.at(1), 'nouveau123'); // mot de passe
    await tester.enterText(fields.at(2), 'nouveau123'); // confirmation
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Mot de passe réinitialisé. Vous pouvez vous connecter.'),
      findsOneWidget,
    );
  });

  testWidgets('un code incorrect affiche une erreur et reste sur l\'écran', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ResetPasswordScreen(phone: '+2250700000000')),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '000000'); // code incorrect
    await tester.enterText(fields.at(1), 'nouveau123');
    await tester.enterText(fields.at(2), 'nouveau123');
    await tester.tap(find.text('Réinitialiser'));
    await tester.pumpAndSettle();

    expect(find.text('Code invalide ou expiré.'), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsOneWidget);
  });

  testWidgets('mots de passe différents affichent une erreur de validation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ResetPasswordScreen(phone: '+2250700000000')),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'nouveau123');
    await tester.enterText(fields.at(2), 'different456');
    await tester.tap(find.text('Réinitialiser'));
    await tester.pump();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });
}
