import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_storage.dart';
import 'api_client.dart';

final authStorageProvider = Provider<AuthStorage>((ref) {
  return AuthStorage(const FlutterSecureStorage());
});

/// Incrémenté quand une session expire (401 + refresh KO) pour que l'UI
/// puisse réagir (déconnexion + retour à Login) sans dépendance circulaire
/// entre ApiClient et les providers d'authentification.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final authStorage = ref.watch(authStorageProvider);
  return ApiClient(
    authStorage,
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).state++,
  );
});
