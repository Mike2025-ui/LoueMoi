import '../config/env.dart';

/// Endpoints REST centralisés, prêts pour un backend Django REST Framework.
/// Aucun appel API ne doit coder une URL en dur ailleurs.
class ApiEndpoints {
  ApiEndpoints._();

  static String get baseUrl => Env.apiBaseUrl;

  // Auth
  static const String login = '/api/auth/login/';
  static const String register = '/api/auth/register/';
  static const String refreshToken = '/api/auth/refresh/';
  static const String logout = '/api/auth/logout/';

  // Properties
  static const String properties = '/api/properties/';
  static String propertyDetail(String id) => '/api/properties/$id/';
  static String propertyReviews(String id) => '/api/properties/$id/reviews/';
  static String propertyFavorite(String id) => '/api/properties/$id/favorite/';
  static String propertyView(String id) => '/api/properties/$id/view/';
  static String propertyUploadImage(String id) => '/api/properties/$id/upload-image/';
  static const String propertiesNearby = '/api/properties/nearby/';

  /// Annonces de l'agent connecté uniquement — filtré côté Django, jamais
  /// en filtrant /api/properties/ côté Flutter.
  static const String myProperties = '/api/agent/properties/';
  static const String agentDashboard = '/api/agent/dashboard/';

  // Reservations
  static const String reservations = '/api/reservations/';
  static String reservationDetail(String id) => '/api/reservations/$id/';
  static String reservationCancel(String id) => '/api/reservations/$id/cancel/';

  // Messages
  static const String conversations = '/api/conversations/';
  static const String messages = '/api/messages/';

  // User
  static const String profile = '/api/users/me/';
}
