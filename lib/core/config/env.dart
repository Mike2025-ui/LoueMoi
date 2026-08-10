import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment { development, staging, production }

/// Configuration par environnement (API_BASE_URL, USE_MOCK_DATA...).
///
/// Choix de l'environnement au lancement :
///   flutter run --dart-define=ENV=development   (défaut)
///   flutter run --dart-define=ENV=staging
///   flutter run --dart-define=ENV=production
///
/// Surcharge ponctuelle sans toucher aux fichiers .env :
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
///   flutter run --dart-define=USE_MOCK_DATA=true
class Env {
  Env._();

  static AppEnvironment _current = AppEnvironment.development;
  static AppEnvironment get current => _current;

  static const String _envNameFromDefine = String.fromEnvironment('ENV', defaultValue: 'development');

  static Future<void> load() async {
    _current = AppEnvironment.values.firstWhere(
      (e) => e.name == _envNameFromDefine,
      orElse: () => AppEnvironment.development,
    );
    await dotenv.load(fileName: _envFile(_current));
  }

  static String _envFile(AppEnvironment env) => switch (env) {
        AppEnvironment.development => 'assets/env/.env.development',
        AppEnvironment.staging => 'assets/env/.env.staging',
        AppEnvironment.production => 'assets/env/.env.production',
      };

  static String get apiBaseUrl {
    const define = String.fromEnvironment('API_BASE_URL');
    if (define.isNotEmpty) return define;

    // dotenv.env lève une exception tant que load() n'a pas été appelé (ex:
    // dans les tests, qui n'appellent volontairement pas Env.load() pour
    // rester isolés du réseau) — on retombe alors sur les valeurs par défaut.
    final fromFile = dotenv.isInitialized ? dotenv.env['API_BASE_URL'] : null;
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;

    if (_current == AppEnvironment.development) {
      // Adresse locale par défaut pour `python manage.py runserver`, sans
      // configuration : 10.0.2.2 est l'alias de l'hôte depuis l'émulateur
      // Android, 127.0.0.1 depuis le simulateur iOS.
      return Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
    }
    return 'https://api.louemoi.example.com';
  }

  /// URL de tuiles carto (flutter_map). Par défaut : serveur public
  /// OpenStreetMap — aucune clé requise, fonctionne dès l'installation.
  /// Surchargeable par environnement (MAP_TILE_URL_TEMPLATE dans
  /// assets/env/.env.*) pour brancher un fournisseur payant en production
  /// sans jamais committer de clé : elle reste dans un fichier .env local,
  /// non versionné.
  static String get mapTileUrlTemplate {
    const define = String.fromEnvironment('MAP_TILE_URL_TEMPLATE');
    if (define.isNotEmpty) return define;
    final fromFile = dotenv.isInitialized ? dotenv.env['MAP_TILE_URL_TEMPLATE'] : null;
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  static bool get useMockData {
    const define = String.fromEnvironment('USE_MOCK_DATA');
    if (define.isNotEmpty) return define.toLowerCase() == 'true';
    // Non initialisé (tests, ou Env.load() pas encore résolu) : mode mock
    // par défaut, pour ne jamais déclencher d'appel réseau involontaire.
    if (!dotenv.isInitialized) return true;
    return (dotenv.env['USE_MOCK_DATA'] ?? 'false').toLowerCase() == 'true';
  }
}
