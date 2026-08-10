import '../models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
}

class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _notifications = [
    AppNotification(
      id: 'n1',
      title: 'Nouveau message',
      message: 'Mme Kouakou vous a envoyé un message à propos de votre demande.',
      type: NotificationType.message,
      createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    AppNotification(
      id: 'n2',
      title: 'Réservation confirmée',
      message: 'Votre réservation pour "Appartement meublé" a été validée.',
      type: NotificationType.reservation,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AppNotification(
      id: 'n3',
      title: 'Nouveau bien disponible',
      message: 'Une Villa correspondant à vos favoris vient d’être publiée à Cocody.',
      type: NotificationType.favorite,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    AppNotification(
      id: 'n4',
      title: 'Bienvenue sur LoueMoi',
      message: 'Complétez votre profil pour profiter de toutes les fonctionnalités.',
      type: NotificationType.system,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
  ];

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_notifications);
  }

  @override
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }
}
