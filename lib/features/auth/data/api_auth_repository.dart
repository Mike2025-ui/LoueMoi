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
    String? whatsapp,
    required String password,
    required UserRole role,
  }) async {
    final effectiveWhatsapp = (whatsapp != null && whatsapp.isNotEmpty) ? whatsapp : phone;
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'whatsapp': effectiveWhatsapp,
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
  Future<void> deactivateAccount(String password) async {
    final refresh = await _authStorage.getRefreshToken();
    // Laisse l'ApiException (401, mot de passe incorrect) remonter telle
    // quelle à l'appelant — la désactivation locale (clearTokens) ne doit
    // jamais avoir lieu si le serveur a refusé la demande.
    await _apiClient.post(
      ApiEndpoints.deactivateAccount,
      data: {'password': password, 'refresh': ?refresh},
    );
    await _authStorage.clearTokens();
  }

  @override
  Future<void> requestPasswordReset(String phone) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.passwordResetRequest,
      data: {'phone': phone},
    );
  }

  @override
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.passwordResetConfirm,
      data: {'phone': phone, 'code': code, 'new_password': newPassword},
    );
  }

  @override
  Future<User?> restoreSession() async {
    final access = await _authStorage.getAccessToken();
    if (access == null) return null;
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.profile,
      );
      return User.fromJson(response.data!);
    } on ApiException {
      return null;
    }
  }

  @override
  Future<User> updateProfile(User current, Map<String, dynamic> changes) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiEndpoints.profile,
      data: changes,
    );
    return User.fromJson(response.data!);
  }

  @override
  Future<User> requestActivation() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.requestActivation,
    );
    return _persistAndParse(response.data!);
  }

  @override
  Future<User> refreshProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.profile,
    );
    return User.fromJson(response.data!);
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
