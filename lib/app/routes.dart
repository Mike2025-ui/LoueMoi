/// Chemins de routes centralisés (go_router). Ne jamais coder une route en
/// dur ailleurs : toujours passer par [AppRoutes].
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';

  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String publish = '/publish';
  static const String reservationsList = '/reservations';
  static const String profile = '/profile';
  static const String agentSpace = '/profile/agent';
  static const String myProperties = '/profile/agent/properties';
  static const String agentDashboard = '/profile/agent/dashboard';

  static const String editProperty = '/publish/edit/:id';
  static String editPropertyPath(String id) => '/publish/edit/$id';

  static const String propertyMap = '/map';

  static const String propertyDetail = '/property/:id';
  static String propertyDetailPath(String id) => '/property/$id';

  static const String propertyGallery = '/property/:id/gallery';
  static String propertyGalleryPath(String id) => '/property/$id/gallery';

  static const String propertyGalleryViewer = '/property/:id/gallery/view';
  static String propertyGalleryViewerPath(String id) =>
      '/property/$id/gallery/view';

  static const String propertyReviews = '/property/:id/reviews';
  static String propertyReviewsPath(String id) => '/property/$id/reviews';

  static const String reservationSummary = '/property/:id/reservation';
  static String reservationSummaryPath(String id) => '/property/$id/reservation';

  static const String reservationConfirmation = '/reservation/confirmation';
  static const String reservationCongrats = '/reservation/congrats';

  static const String filters = '/filters';

  static const String notifications = '/notifications';

  static const String messages = '/messages';
  static const String conversation = '/messages/:id';
  static String conversationPath(String id) => '/messages/$id';
}
