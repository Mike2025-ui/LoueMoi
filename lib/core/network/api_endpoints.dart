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
  static const String passwordResetRequest = '/api/auth/password-reset/request/';
  static const String passwordResetConfirm = '/api/auth/password-reset/confirm/';

  // Properties
  static const String properties = '/api/properties/';
  static String propertyDetail(String id) => '/api/properties/$id/';
  static String propertyReviews(String id) => '/api/properties/$id/reviews/';
  static String propertyFavorite(String id) => '/api/properties/$id/favorite/';
  static String propertyView(String id) => '/api/properties/$id/view/';
  static String propertyUploadImage(String id) => '/api/properties/$id/upload-image/';
  static String propertyUploadVideo(String id) => '/api/properties/$id/video/';
  static String propertyRenew(String id) => '/api/properties/$id/renew/';
  static String propertyMarkStatus(String id) => '/api/properties/$id/status/';
  static const String propertiesNearby = '/api/properties/nearby/';

  /// Annonces de l'agent connecté uniquement — filtré côté Django, jamais
  /// en filtrant /api/properties/ côté Flutter.
  static const String myProperties = '/api/agent/properties/';
  static const String agentDashboard = '/api/agent/dashboard/';
  static const String agentProfileMe = '/api/agent/profile/';
  static const String agentCertificationRequest = '/api/agent/certification/request/';

  /// Même principe que ci-dessus, pour le rôle bailleur — indépendant de
  /// l'agent, jamais le même endpoint.
  static const String bailleurProperties = '/api/bailleur/properties/';
  static const String bailleurDashboard = '/api/bailleur/dashboard/';

  // Agents (recherche publique)
  static const String agentsSearch = '/api/agents/';

  // Bailleurs (recherche publique) — symétrique de agentsSearch.
  static const String bailleursSearch = '/api/bailleurs/';

  // Reservations
  static const String reservations = '/api/reservations/';
  static String reservationDetail(String id) => '/api/reservations/$id/';
  static String reservationCancel(String id) => '/api/reservations/$id/cancel/';
  static String reservationComplete(String id) => '/api/reservations/$id/complete/';
  static String reservationConversation(String id) => '/api/reservations/$id/conversation/';

  // Messages
  static const String conversations = '/api/conversations/';
  static String conversationMarkRead(String id) => '/api/conversations/$id/mark-read/';
  static const String messages = '/api/messages/';

  // User
  static const String profile = '/api/users/me/';
  static const String deactivateAccount = '/api/users/me/deactivate/';

  // Notifications
  static const String notifications = '/api/notifications/';
  static const String notificationsUnreadCount = '/api/notifications/unread-count/';
  static const String notificationsReadAll = '/api/notifications/read-all/';
  static String notificationRead(String id) => '/api/notifications/$id/read/';

  // Device tokens (FCM)
  static const String devices = '/api/devices/';
  static const String devicesDeactivate = '/api/devices/deactivate/';
}
