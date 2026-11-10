/// Chemins de routes centralisés (go_router). Ne jamais coder une route en
/// dur ailleurs : toujours passer par [AppRoutes].
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String pendingActivation = '/pending-activation';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password/:phone';
  static String resetPasswordPath(String phone) =>
      '/reset-password/${Uri.encodeComponent(phone)}';
  static const String verifyOtp = '/verify-otp/:phone';
  static String verifyOtpPath(String phone) =>
      '/verify-otp/${Uri.encodeComponent(phone)}';
  static const String newPassword = '/new-password';
  static String newPasswordPath({required String phone, required String code}) =>
      '/new-password?phone=${Uri.encodeComponent(phone)}&code=${Uri.encodeComponent(code)}';

  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String publish = '/publish';
  static const String reservationsList = '/reservations';
  static const String profile = '/profile';
  static const String personalInfo = '/profile/personal-info';
  static const String editProfile = '/profile/edit';
  static const String contactedProperties = '/profile/contacted-properties';
  static const String myProperties = '/profile/properties';
  static const String agentSpace = '/profile';
  static const String agentDashboard = '/profile';
  static const String soldProperties = '/profile';

  static const String bailleurSpace = '/profile';
  static const String bailleurProperties = '/profile/properties';
  static const String bailleurDashboard = '/profile';

  static const String agentSearch = '/home';

  static const String bailleurSearch = '/home';

  /// Annonces publiques d'un propriétaire donné (agent ou bailleur) — à ne
  /// pas confondre avec [bailleurProperties] ("Mes biens" du bailleur
  /// connecté, ses propres annonces gérées).
  static const String bailleurPublicProperties = '/bailleurs/:id/properties';
  static String bailleurPublicPropertiesPath(String id) => '/bailleurs/$id/properties';

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

  static const String reservationSummary = '/property/:id/reservation';
  static String reservationSummaryPath(String id) => '/property/$id/reservation';

  static const String reservationConfirmation = '/reservation/confirmation';
  static const String reservationCongrats = '/reservation/congrats';

  static const String filters = '/filters';

  static const String notifications = '/notifications';

  static const String messages = '/messages';
  static const String conversation = '/messages/:id';
  static String conversationPath(String id) => '/messages/$id';

  static const String maintenance = '/maintenance';
}
