import 'package:equatable/equatable.dart';

/// Catégorie visuelle (icône/couleur) affichée par NotificationsScreen —
/// l'écran existant est conservé tel quel, seule cette catégorisation
/// dérive maintenant des 8 types réels renvoyés par Django plutôt que
/// d'être choisie manuellement en mode mock.
enum NotificationType {
  message,
  reservation,
  favorite,
  system;
}

/// Types métier exacts renvoyés par Django (Notification.TYPE_CHOICES) —
/// utilisés par NotificationRouter pour la navigation au clic, jamais pour
/// l'affichage (voir [NotificationType] pour ça).
NotificationType _categoryFor(String rawType) => switch (rawType) {
      'new_message' => NotificationType.message,
      'reservation_created' ||
      'reservation_confirmed' ||
      'reservation_cancelled' ||
      'new_reservation' =>
        NotificationType.reservation,
      'property_available' || 'new_favorite' => NotificationType.favorite,
      _ => NotificationType.system,
    };

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.rawType = '',
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final NotificationType type;

  /// Type exact backend (ex: "new_message", "reservation_confirmed"...) —
  /// c'est CE champ que NotificationRouter utilise pour décider de l'écran
  /// à ouvrir, jamais [type] qui n'est qu'une catégorie visuelle.
  final String rawType;

  /// Payload structuré (ex: {"conversation_id": "12"}) — jamais du texte
  /// libre à parser pour la navigation.
  final Map<String, dynamic> data;

  final DateTime createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      type: type,
      rawType: rawType,
      data: data,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? '';
    return AppNotification(
      id: json['id'].toString(),
      title: json['title'] as String? ?? '',
      message: json['body'] as String? ?? '',
      type: _categoryFor(rawType),
      rawType: rawType,
      data: (json['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, title, message, type, rawType, data, createdAt, isRead];
}
