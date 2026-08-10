/// Constantes globales de l'application.
///
/// Toute référence au nom affiché doit passer par [AppConstants.appDisplayName]
/// pour pouvoir être changée en un seul endroit.
class AppConstants {
  AppConstants._();

  static const String appDisplayName = 'LoueMoi';
  static const String appProjectName = 'LoueMoi';

  static const String currencySuffix = 'Fcfa';

  static const List<String> logementCategories = [
    'Villa',
    'Chambre-salon',
    'Studio',
    'Appart',
    'Entrer-coucher',
    'Bureau',
  ];

  static const List<String> terrainCategories = [
    'Terrain nu',
    'Terrain agricole',
    'Terrain loti',
  ];

  static const List<String> magasinCategories = [
    'Boutique',
    'Magasin',
    'Entrepôt',
    'Local commercial',
  ];
}
