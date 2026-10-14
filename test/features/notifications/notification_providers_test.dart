import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/notifications/providers/notification_providers.dart';

/// Régression pour "le badge continue à afficher un nombre même après
/// lecture" (signalé sur téléphone réel). Teste la chaîne complète —
/// MockNotificationRepository fournit un état déterministe (n1/n2 non
/// lues, n3/n4 déjà lues — 2 non lues au départ) — via les VRAIES fonctions
/// markNotificationAsRead/markAllNotificationsAsRead (qui exigent un
/// WidgetRef, capturé ici via un Consumer minimal plutôt que de
/// contourner leur signature).
///
/// tester.runAsync() est nécessaire ici : MockNotificationRepository simule
/// une latence réseau via Future.delayed, qui ne s'écoule jamais sous
/// l'horloge "fake" du test binding sans lui (le test restait bloqué
/// indéfiniment sur `await ...future` avant ce correctif).
Future<WidgetRef> _captureRef(WidgetTester tester) async {
  late WidgetRef capturedRef;
  await tester.pumpWidget(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          capturedRef = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return capturedRef;
}

void main() {
  testWidgets('lire une notification décrémente immédiatement le compteur non-lu',
      (tester) async {
    final ref = await _captureRef(tester);

    await tester.runAsync(() async {
      final initialCount = await ref.read(unreadNotificationsCountProvider.future);
      expect(initialCount, 2, reason: 'MockNotificationRepository: n1 et n2 sont non lues');

      await markNotificationAsRead(ref, 'n1');

      final afterOneRead = await ref.read(unreadNotificationsCountProvider.future);
      expect(afterOneRead, 1);

      final notifications = await ref.read(notificationsProvider.future);
      final n1 = notifications.firstWhere((n) => n.id == 'n1');
      expect(n1.isRead, isTrue);
    });
  });

  testWidgets('marquer tout comme lu remet le compteur à zéro', (tester) async {
    final ref = await _captureRef(tester);

    await tester.runAsync(() async {
      expect(await ref.read(unreadNotificationsCountProvider.future), 2);

      await markAllNotificationsAsRead(ref);

      expect(await ref.read(unreadNotificationsCountProvider.future), 0);

      final notifications = await ref.read(notificationsProvider.future);
      expect(notifications.every((n) => n.isRead), isTrue);
    });
  });

  testWidgets('lire une notification déjà lue ne change rien au compteur', (tester) async {
    final ref = await _captureRef(tester);

    await tester.runAsync(() async {
      expect(await ref.read(unreadNotificationsCountProvider.future), 2);

      // n3 est déjà lue dans MockNotificationRepository.
      await markNotificationAsRead(ref, 'n3');

      expect(await ref.read(unreadNotificationsCountProvider.future), 2);
    });
  });
}
