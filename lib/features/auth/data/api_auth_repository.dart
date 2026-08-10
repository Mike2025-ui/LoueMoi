import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/services/auth_storage.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import 'auth_repository.dart';

/// Implémentation réelle, branchée sur le backend Django (JWT via SimpleJWT).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._apiClient, this._authStorage);

  final ApiClient _apiClient;
  final AuthStorage _authStorage;

  @override
  Future<User> login({required String phone, required String password}) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'phone': phone, 'password': password},
    );
    return _persistAndParse(response.data!);
  }

  @override
  Future<User> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'whatsapp': phone,
        'password': password,
        'password_confirm': password,
        'role': role.toJson(),
      },
    );
    return _persistAndParse(response.data!);
  }

  @override
  Future<void> logout() async {
    final refresh = await _authStorage.getRefreshToken();
    try {
      if (refresh != null) {
        await _apiClient.post(ApiEndpoints.logout, data: {'refresh': refresh});
      }
    } on ApiException {
      // La déconnexion locale doit réussir même si l'appel réseau échoue
      // (session déjà expirée, hors-ligne...).
    } finally {
      await _authStorage.clearTokens();
    }
  }

  @override
  Future<User?> restoreSession() async {
    final access = await _authStorage.getAccessToken();
    if (access == null) return null;
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.profile);
      return User.fromJson(response.data!);
    } on ApiException {
      return null;
    }
  }

  Future<User> _persistAndParse(Map<String, dynamic> data) async {
    final access = data['token'] as String?;
    final refresh = data['refresh'] as String?;
    if (access != null && refresh != null) {
      await _authStorage.saveTokens(access: access, refresh: refresh);
    }
    return User.fromJson(data);
  }
}
