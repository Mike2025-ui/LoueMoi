import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stockage sécurisé des tokens JWT (access + refresh). Jamais en clair,
/// jamais dans SharedPreferences — uniquement flutter_secure_storage
/// (Keychain sur iOS, EncryptedSharedPreferences sur Android).
class AuthStorage {
  AuthStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'auth_access_token';
  static const String _refreshKey = 'auth_refresh_token';

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);

  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
