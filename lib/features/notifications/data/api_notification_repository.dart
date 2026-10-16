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
    final results = response.data!['results'] as List;
    return results
        .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
        .where((n) => n.rawType != 'new_message' && n.type != NotificationType.message)
        .toList();
  }

  @override
  Future<int> fetchUnreadCount() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.notificationsUnreadCount,
    );
    return response.data!['unread_count'] as int;
  }

  @override
  Future<void> markAsRead(String id) async {
    await _apiClient.post<Map<String, dynamic>>(ApiEndpoints.notificationRead(id));
  }

  @override
  Future<void> markAllAsRead() async {
    await _apiClient.post<Map<String, dynamic>>(ApiEndpoints.notificationsReadAll);
  }
}
