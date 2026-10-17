import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';
import 'package:louemoi/features/auth/providers/auth_providers.dart';
import 'package:louemoi/features/auth/screens/pending_activation_screen.dart';

void main() {
  testWidgets('PendingActivationScreen renders request state when not requested yet',
      (tester) async {
    const unapprovedAgent = User(
      id: 'agent-1',
      firstName: 'Kouassi',
      lastName: 'Marc',
      phone: '+2250102030405',
      whatsapp: '+2250708091011',
      role: UserRole.agent,
      isApproved: false,
      activationRequested: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _StaticAuthController(unapprovedAgent),
          ),
        ],
        child: const MaterialApp(home: PendingActivationScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Compte Agent immobilier'), findsOneWidget);
    expect(find.text('Activation de votre compte requise'), findsOneWidget);
    expect(find.text("Demander l'activation du compte"), findsOneWidget);
    expect(find.text('+2250708091011'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('PendingActivationScreen renders waiting state when already requested',
      (tester) async {
    const requestedBailleur = User(
      id: 'bailleur-1',
      firstName: 'Awa',
      lastName: 'Diallo',
      phone: '+2250102030405',
      whatsapp: '+2250506070809',
      role: UserRole.bailleur,
      isApproved: false,
      activationRequested: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            (ref) => _StaticAuthController(requestedBailleur),
          ),
        ],
        child: const MaterialApp(home: PendingActivationScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Compte Bailleur'), findsOneWidget);
    expect(find.text("Votre demande d'activation est en cours"), findsOneWidget);
    expect(find.text("Vérifier le statut d'activation"), findsOneWidget);
    expect(find.text('+2250506070809'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });
}

class _StaticAuthController extends StateNotifier<AsyncValue<User?>>
    implements AuthController {
  _StaticAuthController(User user) : super(AsyncValue.data(user));

  @override
  Future<void> get ready async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

