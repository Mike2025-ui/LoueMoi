import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/api_notification_repository.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  if (Env.useMockData) return MockNotificationRepository();
  return ApiNotificationRepository(ref.watch(apiClientProvider));
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.fetchNotifications();
});

/// Badge — GET /api/notifications/unread-count/ (jamais recompté depuis une
/// liste potentiellement partielle/périmée). Invalidé à la connexion, à la
/// réception d'un push, à l'ouverture de l'écran Notifications et après
/// marquage lu/tout lire (voir les call sites de `ref.invalidate`).
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.fetchUnreadCount();
});

Future<void> markNotificationAsRead(WidgetRef ref, String id) async {
  final repository = ref.read(notificationRepositoryProvider);
  await repository.markAsRead(id);
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadNotificationsCountProvider);
}

Future<void> markAllNotificationsAsRead(WidgetRef ref) async {
  final repository = ref.read(notificationRepositoryProvider);
  await repository.markAllAsRead();
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadNotificationsCountProvider);
}
