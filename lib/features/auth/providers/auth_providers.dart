import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/network_providers.dart';
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
    required String password,
    required UserRole role,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        password: password,
        role: role,
      );
      state = AsyncValue.data(user);
    } on ApiException catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
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
