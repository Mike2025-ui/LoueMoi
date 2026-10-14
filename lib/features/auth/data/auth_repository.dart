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

  /// Désactivation du compte (jamais une suppression physique — décision
  /// métier : `is_active=False` côté Django, toutes les données restent
  /// intactes). Exige le mot de passe en confirmation ; lève une
  /// [ApiException] (401) si le mot de passe est incorrect. Déconnecte
  /// localement en cas de succès, comme [logout].
  Future<void> deactivateAccount(String password);

  /// "Mot de passe oublié" étape 1 — POST /api/auth/password-reset/request/.
  /// Réponse toujours générique côté serveur (jamais d'indice sur
  /// l'existence du numéro) : ne lève jamais d'exception pour "numéro
  /// inconnu", seulement en cas d'erreur réseau/serveur réelle.
  Future<void> requestPasswordReset(String phone);

  /// "Mot de passe oublié" étape 2 — vérifie le code ET change le mot de
  /// passe en un seul appel (POST /api/auth/password-reset/confirm/). Lève
  /// une [ApiException] (400) si le code est invalide/expiré/déjà utilisé.
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  });

  /// Restaure la session depuis le token persisté, s'il est encore valide.
  /// Retourne `null` si aucune session (ou session expirée).
  Future<User?> restoreSession();

  /// PATCH /api/users/me/ — modification du profil (voir "Modification du
  /// profil" du cahier des charges). [changes] ne doit jamais contenir
  /// `role`/`id`/`phone` : en lecture seule ou volontairement exclus côté
  /// Flutter (le numéro de téléphone sert d'identifiant de connexion, jamais
  /// modifiable depuis cet écran). [current] sert de base en mode mock
  /// (aucun état serveur persisté) — ignoré par l'implémentation API, qui
  /// fait toujours confiance à la réponse serveur.
  Future<User> updateProfile(User current, Map<String, dynamic> changes);
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
  Future<void> deactivateAccount(String password) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (password.isEmpty) {
      throw const UnauthorizedException('Mot de passe incorrect.');
    }
  }

  @override
  Future<void> requestPasswordReset(String phone) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // Toujours un succès silencieux, même en mode mock — jamais d'indice
    // sur l'existence du numéro, même dans la démo.
  }

  @override
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (code != '123456') {
      throw const ValidationException('Code invalide ou expiré.');
    }
  }

  @override
  Future<User?> restoreSession() async => null;

  @override
  Future<User> updateProfile(User current, Map<String, dynamic> changes) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return User.fromJson({...current.toJson(), ...changes});
  }
}
