import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/app_notification.dart';
import 'notification_repository.dart';

/// Implémentation réelle, branchée sur /api/notifications/. Un utilisateur
/// ne récupère jamais que ses propres notifications — filtrage garanti côté
/// Django (recipient=request.user), jamais recalculé ici.
class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
      query: {'page_size': 100},
    );
    final data = response.data;
    if (data == null) return const [];
    final rawResults = data['results'] ?? data;
    if (rawResults is! List) return const [];
    final results = <AppNotification>[];
    for (final item in rawResults) {
      if (item is Map) {
        try {
          final n = AppNotification.fromJson(Map<String, dynamic>.from(item));
          if (n.rawType != 'new_message' && n.type != NotificationType.message) {
            results.add(n);
          }
        } catch (_) {}
      }
    }
    return results;
  }

  @override
  Future<int> fetchUnreadCount() async {
    try {
      final notifications = await fetchNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.notificationRead(id),
    );
  }

  @override
  Future<void> markAllAsRead() async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.notificationsReadAll,
    );
  }
}
