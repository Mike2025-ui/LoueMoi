/// Chemins d'assets centralisés. Le code ne doit jamais coder un chemin
/// d'asset en dur ailleurs que dans ce fichier.
class AppAssets {
  AppAssets._();

  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';

  static const String loginIllustration =
      '$_images/illustrations/login_illustration.jpg';

  static const String onboarding1 = '$_images/onboarding/onboarding_1.jpg';
  static const String onboarding2 = '$_images/onboarding/onboarding_2.jpg';

  static const List<String> propertyPhotos = [
    '$_images/properties/property_exterior_1.jpg',
    '$_images/properties/property_exterior_2.jpg',
    '$_images/properties/property_interior_1.jpg',
    '$_images/properties/property_exterior_3.jpg',
    '$_images/properties/property_exterior_4.jpg',
  ];

  static const String navFavoris = '$_icons/nav_favoris.png';
  static const String navReserves = '$_icons/nav_reserves.png';
  static const String navProfil = '$_icons/nav_profil.png';
  static const String navMenu = '$_icons/nav_menu.png';
}
