import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/services/fcm_service.dart';
import '../data/device_token_repository.dart';

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  if (Env.useMockData) return MockDeviceTokenRepository();
  return ApiDeviceTokenRepository(ref.watch(apiClientProvider));
});

/// Dernier token FCM connu — retenu uniquement pour pouvoir le désactiver
/// proprement à la déconnexion (POST /api/devices/deactivate/).
final currentFcmTokenProvider = StateProvider<String?>((ref) => null);

/// Appelé après une connexion réussie (voir app/app.dart, écoute de
/// authControllerProvider) : récupère le token FCM et l'associe à
/// l'utilisateur connecté. Réagit aussi aux rafraîchissements de token
/// (onTokenRefresh) tant que l'écoute reste active. Ne fait jamais planter
/// le flux de connexion : USE_MOCK_DATA=true ne déclenche aucun appel
/// Firebase ni Django réel.
Future<void> syncDeviceTokenOnLogin(WidgetRef ref) async {
  if (Env.useMockData) return;
  try {
    await FcmService().initialize(
      onToken: (token) async {
        ref.read(currentFcmTokenProvider.notifier).state = token;
        try {
          final platform = Platform.isIOS ? 'ios' : 'android';
          await ref.read(deviceTokenRepositoryProvider).register(token, platform);
        } catch (_) {
          // Un souci réseau au moment d'associer le token ne doit jamais
          // bloquer la connexion — la prochaine ouverture de l'app
          // retentera via onTokenRefresh ou un nouvel appel à ce flux.
        }
      },
    );
  } catch (_) {}
}

/// Appelé à la déconnexion : désactive le token côté Django (jamais
/// suppression de l'historique de notifications, seulement le token).
Future<void> deactivateDeviceTokenOnLogout(WidgetRef ref) async {
  if (Env.useMockData) return;
  final token = ref.read(currentFcmTokenProvider);
  if (token == null) return;
  try {
    await ref.read(deviceTokenRepositoryProvider).deactivate(token);
  } catch (_) {}
  ref.read(currentFcmTokenProvider.notifier).state = null;
}
