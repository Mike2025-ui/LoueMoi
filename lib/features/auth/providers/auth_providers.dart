import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/network_providers.dart';
import '../../profile/models/agent_profile.dart';
import '../data/api_auth_repository.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';
import '../models/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useMockData) return MockAuthRepository();
  return ApiAuthRepository(ref.watch(apiClientProvider), ref.watch(authStorageProvider));
});

/// État d'authentification global de l'application. Démarre en `loading` le
/// temps de tenter une restauration de session (token déjà stocké).
class AuthController extends StateNotifier<AsyncValue<User?>> {
  AuthController(this._repository) : super(const AsyncValue.loading()) {
    _restoreSession();
  }

  final AuthRepository _repository;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Se résout une fois la tentative de restauration de session terminée
  /// (utilisé par le Splash pour savoir où naviguer).
  Future<void> get ready => _readyCompleter.future;

  Future<void> _restoreSession() async {
    try {
      final user = await _repository.restoreSession();
      state = AsyncValue.data(user);
    } catch (_) {
      state = const AsyncValue.data(null);
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  Future<void> login({required String phone, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(phone: phone, password: password);
      state = AsyncValue.data(user);
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    String? whatsapp,
    required String password,
    required UserRole role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        whatsapp: whatsapp,
        password: password,
        role: role,
      );
      state = AsyncValue.data(user);
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> requestActivation() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final updated = await _repository.requestActivation();
      state = AsyncValue.data(updated);
    } catch (e) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final updated = await _repository.refreshProfile();
      state = AsyncValue.data(updated);
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  /// Désactivation du compte — voir [AuthRepository.deactivateAccount].
  /// Propage l'exception (mot de passe incorrect) à l'appelant sans changer
  /// l'état : l'utilisateur reste connecté tant que le mot de passe n'est
  /// pas confirmé.
  Future<void> deactivateAccount(String password) async {
    await _repository.deactivateAccount(password);
    state = const AsyncValue.data(null);
  }

  /// PATCH /api/users/me/ — "Modification du profil". Met à jour l'état
  /// d'authentification avec la réponse serveur (source de vérité), pour
  /// que tous les écrans qui lisent authControllerProvider (bell, écrans
  /// agent/bailleur, etc.) reflètent immédiatement les nouvelles données.
  Future<void> updateProfile(Map<String, dynamic> changes) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = await _repository.updateProfile(current, changes);
    state = AsyncValue.data(updated);
  }

  /// Reflète localement un AgentProfile fraîchement mis à jour (voir
  /// AgentProfileRepository.updateAgentProfile, distinct de /api/users/me/) —
  /// évite un rechargement complet de session juste pour ça.
  void applyUpdatedAgentProfile(AgentProfile profile) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      User(
        id: current.id,
        firstName: current.firstName,
        lastName: current.lastName,
        phone: current.phone,
        whatsapp: current.whatsapp,
        photo: current.photo,
        token: current.token,
        role: current.role,
        agentProfile: profile,
      ),
    );
  }

  /// Appelé quand l'intercepteur détecte une session expirée (401 + refresh
  /// KO) : déconnexion locale immédiate, sans nouvel appel réseau.
  void forceLogout() {
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<User?>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth.valueOrNull != null;
});
