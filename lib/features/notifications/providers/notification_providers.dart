import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';
import '../models/app_notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository();
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final repository = ref.watch(notificationRepositoryProvider);
  return repository.fetchNotifications();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? const [];
  return notifications.where((n) => !n.isRead).length;
});

Future<void> markNotificationAsRead(WidgetRef ref, String id) async {
  final repository = ref.read(notificationRepositoryProvider);
  await repository.markAsRead(id);
  ref.invalidate(notificationsProvider);
}

Future<void> markAllNotificationsAsRead(WidgetRef ref) async {
  final repository = ref.read(notificationRepositoryProvider);
  await repository.markAllAsRead();
  ref.invalidate(notificationsProvider);
}
