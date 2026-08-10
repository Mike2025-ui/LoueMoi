/// Échelle d'espacement centralisée (marges, paddings, gaps).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;

  /// Marge horizontale standard des écrans (observée sur les captures).
  static const double screenPadding = 20;
}

/// Rayons de bordure centralisés.
class AppRadius {
  AppRadius._();

  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;

  /// Boutons / champs en pilule (observés sur toutes les captures).
  static const double pill = 28;

  /// Badges de statut (Location / Vente / Occupée).
  static const double badge = 12;
}

/// Tailles standardisées de composants.
class AppSizes {
  AppSizes._();

  static const double fieldHeight = 52;
  static const double buttonHeight = 52;
  static const double iconButtonSize = 40;
  static const double bottomNavHeight = 64;
  static const double fabSize = 56;
  static const double avatarSm = 40;
  static const double avatarMd = 56;
  static const double avatarLg = 96;
}
