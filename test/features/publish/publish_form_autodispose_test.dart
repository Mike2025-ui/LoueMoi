import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/auth/data/auth_repository.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';
import 'package:louemoi/features/auth/providers/auth_providers.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/properties/providers/property_providers.dart';
import 'package:louemoi/features/publish/screens/publish_screen.dart';

/// Régression pour une course entre PublishScreen._loadInitial() et
/// publishFormProvider (autoDispose).
///
/// Cause exacte : _loadInitial() (appelée depuis initState() via
/// addPostFrameCallback) écrit l'état chargé sur publishFormProvider via
/// ref.read(...).state = ..., AVANT que la première page du PageView (la
/// SEULE à observer ce provider via ref.watch) ne soit montée — celle-ci
/// n'apparaît qu'une fois _loadingInitial passé à false, par ce même appel.
/// Avec `StateProvider.autoDispose`, un provider sans aucun watcher actif
/// est éligible à disposition dès la fin du frame/microtask courant :
/// l'écriture réalisée pendant cette fenêtre sans observateur était donc
/// perdue, et le formulaire d'édition revenait silencieusement à son état
/// par défaut (vide) au lieu des données réelles de l'annonce — reproduit
/// ci-dessous avec un dépôt dont fetchPropertyById répond après un vrai
/// délai réseau (200ms, comme MockPropertyRepository), exactement la
/// fenêtre pendant laquelle la course se produisait.
///
/// Corrigé en retirant `.autoDispose` de publishFormProvider
/// (publish_form_provider.dart) : le cycle de vie de cet état est de toute
/// façon déjà entièrement piloté par PublishScreen elle-même (réinitialisé
/// explicitement à CHAQUE ouverture, en création comme en édition), donc
/// autoDispose n'apportait aucun bénéfice réel, seulement ce risque de
/// perte de données.
class _FakeAuthRepository extends MockAuthRepository {
  _FakeAuthRepository(this._user);
  final User _user;
  @override
  Future<User?> restoreSession() async => _user;
}

class _FakeDelayedRepository extends MockPropertyRepository {
  _FakeDelayedRepository(this._property);
  final Property _property;

  @override
  Future<Property> fetchPropertyById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _property;
  }
}

void main() {
  const agentUser = User(
    id: 'a1', firstName: 'Mme', lastName: 'Kouakou',
    phone: '+225070000000', whatsapp: '+225070000000', role: UserRole.agent,
  );

  Property makeProperty() {
    return Property(
      id: 'p1',
      title: 'TITRE ORIGINAL UNIQUE',
      description: 'Description originale.',
      type: PropertyType.logement,
      category: 'Villa',
      transactionType: TransactionType.location,
      price: 500000,
      city: 'Abidjan',
      commune: 'Cocody',
      district: 'Vallon',
      address: '',
      status: PropertyStatus.disponible,
      images: const [],
      coverImage: '',
      features: const [],
      amenities: const [],
      agent: const Agent(id: 'a1', firstName: 'Mme', lastName: 'Kouakou', phone: '', whatsapp: ''),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  testWidgets(
      'formulaire d\'édition : les valeurs réelles de l\'annonce survivent au chargement async '
      'sans réécriture manuelle', (tester) async {
    final property = makeProperty();

    final container = ProviderContainer(
      overrides: [
        authControllerProvider
            .overrideWith((ref) => AuthController(_FakeAuthRepository(agentUser))),
        propertyRepositoryProvider.overrideWithValue(_FakeDelayedRepository(property)),
      ],
    );
    addTearDown(container.dispose);
    // Résout la restauration de session immédiatement (sinon PublishScreen
    // affiche d'abord son écran "réservé aux agents" pendant que
    // authControllerProvider est encore en AsyncValue.loading()).
    container.read(authControllerProvider.notifier).state = AsyncValue.data(agentUser);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PublishScreen(editPropertyId: property.id)),
      ),
    );

    // Laisse initState -> addPostFrameCallback -> _loadInitial() -> le délai
    // réseau simulé (200ms) s'écouler complètement, EXACTEMENT la fenêtre où
    // la course se produisait.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Step 0 (transaction/type) : les dropdowns reflètent déjà les valeurs
    // réelles de la propriété (transactionType=location, type=logement) —
    // preuve que l'état chargé a bien survécu, pas seulement le titre.
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Logement'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    // Step 1 (informations générales) : le titre/la description/le loyer
    // doivent afficher les vraies données de l'annonce, sans qu'aucun code
    // de test n'ait eu besoin de les réécrire manuellement.
    expect(find.widgetWithText(TextField, 'TITRE ORIGINAL UNIQUE'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Description originale.'), findsOneWidget);
    expect(find.widgetWithText(TextField, '500000'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('nouvelle publication (pas une édition) : le formulaire démarre bien vide',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider
            .overrideWith((ref) => AuthController(_FakeAuthRepository(agentUser))),
        propertyRepositoryProvider.overrideWithValue(MockPropertyRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider.notifier).state = AsyncValue.data(agentUser);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PublishScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, ''), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
