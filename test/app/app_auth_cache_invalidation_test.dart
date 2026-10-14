import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louemoi/app/app.dart';
import 'package:louemoi/app/router.dart';
import 'package:louemoi/features/auth/data/auth_repository.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';
import 'package:louemoi/features/auth/providers/auth_providers.dart';
import 'package:louemoi/features/notifications/data/notification_repository.dart';
import 'package:louemoi/features/notifications/models/app_notification.dart';
import 'package:louemoi/features/notifications/providers/notification_providers.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/providers/property_providers.dart';

/// Régression : notificationsProvider et favoritesListProvider ne sont pas
/// autoDispose (voir commentaire dans app.dart) — leur contenu doit survivre
/// à un démontage temporaire de l'écran qui les affiche. Mais sans
/// invalidation explicite au changement de compte (déconnexion/reconnexion
/// dans la même session app, sans redémarrage), les notifications/favoris de
/// l'utilisateur précédent restaient visibles jusqu'au prochain déclenchement
/// naturel (ouverture de l'écran Notifications, ou un ajout/retrait de
/// favori) — un vrai risque de fuite d'un compte à l'autre sur un même
/// appareil. Corrigé en étendant le `ref.listen(authControllerProvider)` déjà
/// présent dans app.dart (même bloc que la synchronisation du token FCM) pour
/// invalider aussi ces deux providers à chaque transition connecté/
/// déconnecté, dans les deux sens.
void main() {
  const user = User(
    id: 'u1',
    firstName: 'Awa',
    lastName: 'Traoré',
    phone: '+225070000001',
    whatsapp: '+225070000001',
    role: UserRole.client,
  );

  testWidgets(
      'changement de compte (connexion/déconnexion) invalide notifications et favoris',
      (tester) async {
    var notifCalls = 0;
    var favCalls = 0;

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith((ref) => AuthController(_FakeAuthRepository())),
        notificationRepositoryProvider
            .overrideWithValue(_CountingNotificationRepo(() => notifCalls++)),
        propertyRepositoryProvider.overrideWithValue(_CountingPropertyRepo(() => favCalls++)),
        routerProvider.overrideWithValue(_testRouter()),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider.notifier).state = const AsyncValue.data(null);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const LoueMoiApp()),
    );
    await tester.pumpAndSettle();

    // Établit un état "périmé" : une première lecture de chaque provider,
    // comme le ferait l'écran Notifications/Favoris en conditions réelles,
    // avant même une connexion.
    container.read(notificationsProvider);
    container.read(favoritesListProvider);
    await tester.pump();
    expect(notifCalls, 1);
    expect(favCalls, 1);

    // Connexion : la transition déconnecté→connecté doit invalider les
    // deux — une relecture doit redéclencher un vrai appel réseau, pas
    // renvoyer une valeur mise en cache pour "personne".
    container.read(authControllerProvider.notifier).state = const AsyncValue.data(user);
    await tester.pump();
    container.read(notificationsProvider);
    container.read(favoritesListProvider);
    await tester.pump();
    expect(notifCalls, 2);
    expect(favCalls, 2);

    // Déconnexion : même garantie dans l'autre sens (évite qu'un compte B
    // qui se connecte ensuite sur le même appareil hérite des données du
    // compte A affichées ici avant la vraie déconnexion serveur).
    container.read(authControllerProvider.notifier).state = const AsyncValue.data(null);
    await tester.pump();
    container.read(notificationsProvider);
    container.read(favoritesListProvider);
    await tester.pump();
    expect(notifCalls, 3);
    expect(favCalls, 3);

    expect(tester.takeException(), isNull);
  });
}

GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: SizedBox())),
    ],
  );
}

class _FakeAuthRepository extends MockAuthRepository {
  @override
  Future<User?> restoreSession() async => null;
}

class _CountingNotificationRepo extends MockNotificationRepository {
  _CountingNotificationRepo(this.onFetch);
  final void Function() onFetch;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    onFetch();
    return [];
  }
}

class _CountingPropertyRepo extends MockPropertyRepository {
  _CountingPropertyRepo(this.onFetch);
  final void Function() onFetch;

  @override
  Future<List<Property>> fetchFavorites() async {
    onFetch();
    return [];
  }
}
