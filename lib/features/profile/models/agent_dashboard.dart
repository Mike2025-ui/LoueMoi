import 'package:equatable/equatable.dart';

/// Statistiques réelles de l'espace agent — jamais de valeurs codées en dur,
/// toujours calculées côté Django (GET /api/agent/dashboard/).
class AgentDashboard extends Equatable {
  const AgentDashboard({
    required this.propertiesCount,
    required this.availableCount,
    required this.occupiedCount,
    required this.reservationsCount,
    required this.favoritesReceived,
    required this.viewsCount,
    required this.messagesCount,
    required this.reviewsCount,
    required this.averageRating,
  });

  final int propertiesCount;
  final int availableCount;
  final int occupiedCount;
  final int reservationsCount;
  final int favoritesReceived;
  final int viewsCount;
  final int messagesCount;
  final int reviewsCount;
  final double averageRating;

  factory AgentDashboard.fromJson(Map<String, dynamic> json) {
    return AgentDashboard(
      propertiesCount: json['properties_count'] as int? ?? 0,
      availableCount: json['available_count'] as int? ?? 0,
      occupiedCount: json['occupied_count'] as int? ?? 0,
      reservationsCount: json['reservations_count'] as int? ?? 0,
      favoritesReceived: json['favorites_received'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      messagesCount: json['messages_count'] as int? ?? 0,
      reviewsCount: json['reviews_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static const empty = AgentDashboard(
    propertiesCount: 0,
    availableCount: 0,
    occupiedCount: 0,
    reservationsCount: 0,
    favoritesReceived: 0,
    viewsCount: 0,
    messagesCount: 0,
    reviewsCount: 0,
    averageRating: 0,
  );

  @override
  List<Object?> get props => [
        propertiesCount,
        availableCount,
        occupiedCount,
        reservationsCount,
        favoritesReceived,
        viewsCount,
        messagesCount,
        reviewsCount,
        averageRating,
      ];
}
