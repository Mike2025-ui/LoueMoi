import '../../../core/network/api_exceptions.dart';
import '../../profile/models/agent_profile.dart';
import '../models/user.dart';
import '../models/user_role.dart';

/// Contrat d'authentification (JWT côté Django).
abstract class AuthRepository {
  Future<User> login({required String phone, required String password});
  Future<User> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required UserRole role,
  });
  Future<void> logout();

  /// Restaure la session depuis le token persisté, s'il est encore valide.
  /// Retourne `null` si aucune session (ou session expirée).
  Future<User?> restoreSession();
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<User> login({required String phone, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (phone.isEmpty || password.isEmpty) {
      throw const UnauthorizedException('Numéro de téléphone ou mot de passe invalide.');
    }
    return User(
      id: 'user-1',
      firstName: 'Jean',
      lastName: 'Kouassi',
      phone: phone,
      whatsapp: phone,
      token: 'mock-token-123',
    );
  }

  @override
  Future<User> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required UserRole role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return User(
      id: 'user-1',
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      whatsapp: phone,
      token: 'mock-token-123',
      role: role,
      agentProfile: role == UserRole.agent
          ? const AgentProfile(
              agencyName: '',
              whatsapp: '',
              description: '',
              isVerified: false,
              rating: 0,
            )
          : null,
    );
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<User?> restoreSession() async => null;
}
