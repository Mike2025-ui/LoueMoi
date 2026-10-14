import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:louemoi/features/notifications/data/notification_repository.dart';
import 'package:louemoi/features/notifications/models/app_notification.dart';
import 'package:louemoi/features/notifications/providers/notification_providers.dart';
import 'package:louemoi/features/notifications/screens/notifications_screen.dart';

/// Régression : "clique sur une notification de message → ouverture directe
/// de la bonne conversation" + "notification devient lue → badge diminue
/// immédiatement" (signalés sur téléphone réel).
///
/// Repository de test dédié, sans latence artificielle : MockNotificationRepository
/// simule un délai réseau via Future.delayed, qui ne s'écoule pas de façon
/// fiable sous pumpAndSettle() dans ce projet (déjà rencontré et corrigé de
/// la même façon pour MainBottomNav — voir main_bottom_nav_test.dart). Le
/// comportement testé ici (lecture au clic, invalidation, navigation) est
/// entièrement dans markNotificationAsRead/NotificationsScreen, pas dans le
/// repository — seul son délai est court-circuité.
class _InstantNotificationRepository implements NotificationRepository {
  final List<AppNotification> notifications = [
    AppNotification(
      id: 'n1',
      title: 'Nouveau message',
      message: 'Mme Kouakou vous a envoyé un message.',
      type: NotificationType.message,
      rawType: 'new_message',
      data: const {'conversation_id': 'conv-1'},
      createdAt: DateTime.now(),
    ),
    AppNotification(
      id: 'n2',
      title: 'Réservation confirmée',
      message: 'Votre réservation a été validée.',
      type: NotificationType.reservation,
      rawType: 'reservation_confirmed',
      data: const {'reservation_id': '1'},
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<AppNotification>> fetchNotifications() async => List.unmodifiable(notifications);

  @override
  Future<int> fetchUnreadCount() async => notifications.where((n) => !n.isRead).length;

  @override
  Future<void> markAsRead(String id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) notifications[index] = notifications[index].copyWith(isRead: true);
  }

  @override
  Future<void> markAllAsRead() async {
    for (var i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }
}

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(
        path: '/messages/:id',
        builder: (c, s) => Scaffold(
          body: Center(child: Text('conversation-${s.pathParameters['id']}')),
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('taper une notification non lue la marque lue et ouvre la conversation',
      (tester) async {
    final repository = _InstantNotificationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: _buildTestRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouveau message'), findsOneWidget);
    expect(repository.notifications.where((n) => !n.isRead).length, 2);

    await tester.tap(find.text('Nouveau message'));
    await tester.pumpAndSettle();

    // Navigation vers la conversation réelle (conv-1), pas un écran générique.
    expect(find.text('conversation-conv-1'), findsOneWidget);

    // Le badge doit refléter la lecture sans qu'il faille revenir en
    // arrière ni relancer l'app.
    expect(repository.notifications.where((n) => !n.isRead).length, 1);
    expect(repository.notifications.firstWhere((n) => n.id == 'n1').isRead, isTrue);
  });

  testWidgets('"Tout lire" remet le compteur non-lu à zéro', (tester) async {
    final repository = _InstantNotificationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: _buildTestRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.notifications.where((n) => !n.isRead).length, 2);

    await tester.tap(find.text('Tout lire'));
    await tester.pumpAndSettle();

    expect(repository.notifications.where((n) => !n.isRead).length, 0);
  });
}
