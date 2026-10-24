import '../../app/routes.dart';

/// Décide de l'écran à ouvrir pour une notification donnée — pure fonction
/// de routage, sans dépendance à BuildContext/GoRouter, pour rester
/// trivialement testable. N'invente aucun écran qui n'existe pas déjà
/// (pas de "ReservationDetailScreen" : les notifications de réservation
/// ouvrent la liste existante).
class NotificationRouter {
  const NotificationRouter();

  /// Retourne le chemin GoRouter à ouvrir, ou `null` si le type est inconnu
  /// ou si les données nécessaires sont absentes — un push manqué ne doit
  /// jamais faire planter l'app, juste ne rien faire.
  String? resolvePath(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'new_message':
        final conversationId = data['conversation_id']?.toString();
        return conversationId == null ? null : AppRoutes.conversationPath(conversationId);

      case 'reservation_created':
      case 'reservation_confirmed':
      case 'reservation_cancelled':
      case 'new_reservation':
        return AppRoutes.reservationsList;

      case 'property_occupied':
      case 'property_available':
      case 'new_favorite':
        final propertyId = data['property_id']?.toString();
        return propertyId == null ? null : AppRoutes.propertyDetailPath(propertyId);

      case 'new_review':
        // Pas d'écran dédié "avis" : les avis d'une annonce s'affichent dans
        // l'onglet "Avis" de PropertyDetailScreen, jamais une route séparée
        // (AppRoutes.propertyReviews n'est enregistrée dans aucune GoRoute —
        // y renvoyer plantait la navigation avec une "no matching route").
        final propertyId = data['property_id']?.toString();
        return propertyId == null ? null : AppRoutes.propertyDetailPath(propertyId);

      case 'admin_broadcast':
      case 'subscription_expiring':
      case 'subscription_expired':
        return AppRoutes.notifications;

      default:
        return null;
    }
  }
}
