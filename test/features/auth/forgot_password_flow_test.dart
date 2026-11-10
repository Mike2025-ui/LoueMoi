import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louemoi/app/routes.dart';
import 'package:louemoi/features/auth/screens/forgot_password_screen.dart';
import 'package:louemoi/features/auth/screens/login_screen.dart';
import 'package:louemoi/features/auth/screens/new_password_screen.dart';
import 'package:louemoi/features/auth/screens/verify_otp_screen.dart';

/// "Mot de passe oublié" :
/// Étape 1 : Numéro de téléphone → Envoi OTP SMS.
/// Étape 2 : Vérification du code OTP alphanumérique (écran dédié).
/// Étape 3 : Saisie du nouveau mot de passe (écran séparé, accessible après validation).
/// Étape 4 : Redirection vers Connexion.
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
          path: AppRoutes.verifyOtp,
          builder: (c, s) => VerifyOtpScreen(
            phone: Uri.decodeComponent(s.pathParameters['phone']!),
          ),
        ),
        GoRoute(
          path: AppRoutes.newPassword,
          builder: (c, s) {
            final phone = s.uri.queryParameters['phone'] ?? '';
            final code = s.uri.queryParameters['code'] ?? '';
            return NewPasswordScreen(phone: phone, code: code);
          },
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

  testWidgets('flux complet réussi : téléphone → vérification code alphanumérique → nouvel écran mot de passe → retour login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: buildRouter())),
    );
    await tester.pump();

    await tester.tap(find.text('Mot de passe oublié ?'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '+2250700000000');
    await tester.tap(find.text('Envoyer le code'));
    await tester.pumpAndSettle();

    // Doit être sur l'écran de vérification OTP
    expect(find.byType(VerifyOtpScreen), findsOneWidget);
    expect(find.textContaining('+2250700000000'), findsOneWidget);

    // Saisie du code alphanumérique (ex: ABC123 ou 123456)
    final otpField = find.byType(TextFormField);
    expect(otpField, findsOneWidget);
    await tester.enterText(otpField, 'ABC123');
    await tester.tap(find.text('Vérifier le code'));
    await tester.pumpAndSettle();

    // Doit basculer vers le NOUVEL écran dédié au mot de passe
    expect(find.byType(NewPasswordScreen), findsOneWidget);
    expect(find.text('Nouveau mot de passe'), findsWidgets);

    // Saisie des mots de passe
    final passwordFields = find.byType(TextFormField);
    expect(passwordFields, findsNWidgets(2));
    await tester.enterText(passwordFields.at(0), 'nouveau123'); // mot de passe
    await tester.enterText(passwordFields.at(1), 'nouveau123'); // confirmation
    await tester.tap(find.text('Enregistrer le mot de passe'));
    await tester.pumpAndSettle();

    // Succès et retour vers Login
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Mot de passe réinitialisé. Vous pouvez vous connecter.'),
      findsOneWidget,
    );
  });

  testWidgets('un code alphanumérique incorrect affiche une erreur et reste sur l\'écran OTP', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: VerifyOtpScreen(phone: '+2250700000000')),
      ),
    );

    final field = find.byType(TextFormField);
    await tester.enterText(field, '999999'); // code incorrect
    await tester.tap(find.text('Vérifier le code'));
    await tester.pumpAndSettle();

    expect(find.text('Code invalide ou expiré.'), findsOneWidget);
    expect(find.byType(VerifyOtpScreen), findsOneWidget);
  });

  testWidgets('mots de passe différents affichent une erreur de validation sur le nouvel écran', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NewPasswordScreen(
            phone: '+2250700000000',
            code: 'ABC123',
          ),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'nouveau123');
    await tester.enterText(fields.at(1), 'different456');
    await tester.tap(find.text('Enregistrer le mot de passe'));
    await tester.pump();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
  });
}
