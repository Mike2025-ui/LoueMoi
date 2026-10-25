import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/network_providers.dart';

/// Modèle de configuration dynamique pilotée par le serveur Django (`/api/config/app-settings/`).
class RemoteAppConfig {
  const RemoteAppConfig({
    this.appVersion = '1.0.0+1',
    this.minSupportedVersion = '1.0.0',
    this.otaAutoUpdateEnabled = true,
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
    this.announcementEnabled = false,
    this.announcementTitle = '',
    this.announcementBody = '',
    this.clientPriceFcfa = 1000,
    this.proPriceFcfa = 3000,
    this.enabledPaymentMethods = const ['wave', 'orange', 'mtn', 'moov'],
    this.supportWhatsapp = '+2250702065206',
  });

  final String appVersion;
  final String minSupportedVersion;
  final bool otaAutoUpdateEnabled;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final bool announcementEnabled;
  final String announcementTitle;
  final String announcementBody;
  final int clientPriceFcfa;
  final int proPriceFcfa;
  final List<String> enabledPaymentMethods;
  final String supportWhatsapp;

  factory RemoteAppConfig.fromJson(Map<String, dynamic> json) {
    final announcement = (json['announcement'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pricing = (json['pricing'] as Map?)?.cast<String, dynamic>() ?? const {};
    final methodsRaw = json['enabled_payment_methods'];
    final methods = methodsRaw is List
        ? methodsRaw.map((e) => e.toString()).toList()
        : const ['wave', 'orange', 'mtn', 'moov'];

    return RemoteAppConfig(
      appVersion: json['app_version']?.toString() ?? '1.0.0+1',
      minSupportedVersion: json['min_supported_version']?.toString() ?? '1.0.0',
      otaAutoUpdateEnabled: json['ota_auto_update_enabled'] as bool? ?? true,
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      maintenanceMessage: json['maintenance_message']?.toString() ?? '',
      announcementEnabled: announcement['enabled'] as bool? ?? false,
      announcementTitle: announcement['title']?.toString() ?? '',
      announcementBody: announcement['body']?.toString() ?? '',
      clientPriceFcfa: (pricing['client_fcfa'] as num?)?.toInt() ?? 1000,
      proPriceFcfa: (pricing['pro_fcfa'] as num?)?.toInt() ?? 3000,
      enabledPaymentMethods: methods,
      supportWhatsapp: json['support_whatsapp']?.toString() ?? '+2250702065206',
    );
  }
}

/// Service combinant :
/// - Solution 1 : Shorebird Code Push (téléchargement et application silencieuse des patchs Dart/Flutter en tâche de fond, sans bouton et sans Play Store)
/// - Solution 2 : Server-Driven Config (synchronisation silencieuse de la configuration temps réel depuis le VPS Django)
class OtaAndRemoteConfigService {
  OtaAndRemoteConfigService(this._apiClient);

  final ApiClient _apiClient;
  final ShorebirdUpdater _updater = ShorebirdUpdater();
  bool _isCheckingPatch = false;

  /// Récupère la configuration dynamique depuis le VPS Django et lance en parallèle
  /// la vérification et le téléchargement silencieux d'un patch OTA Shorebird.
  Future<RemoteAppConfig> syncSilently() async {
    var config = const RemoteAppConfig();
    if (!Env.useMockData) {
      try {
        final response = await _apiClient.get<Map<String, dynamic>>(
          ApiEndpoints.appConfig,
        );
        final data = response.data;
        if (data != null) {
          config = RemoteAppConfig.fromJson(data);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[RemoteConfig] Synchronisation silencieuse ignorée : $e');
        }
      }
    }

    if (config.otaAutoUpdateEnabled && !kIsWeb) {
      _checkAndDownloadShorebirdPatchSilently();
    }

    return config;
  }

  /// Vérifie et télécharge silencieusement tout nouveau patch Shorebird en arrière-plan
  /// sans afficher aucun bouton ni boîte de dialogue à l'utilisateur.
  Future<void> _checkAndDownloadShorebirdPatchSilently() async {
    if (_isCheckingPatch) return;
    _isCheckingPatch = true;
    try {
      if (!_updater.isAvailable) return;
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _updater.update();
        if (kDebugMode) {
          debugPrint('[Shorebird OTA] Patch téléchargé silencieusement en arrière-plan.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Shorebird OTA] Vérification silencieuse : $e');
      }
    } finally {
      _isCheckingPatch = false;
    }
  }
}

final otaAndRemoteConfigServiceProvider = Provider<OtaAndRemoteConfigService>((ref) {
  return OtaAndRemoteConfigService(ref.watch(apiClientProvider));
});

final remoteAppConfigProvider = FutureProvider<RemoteAppConfig>((ref) async {
  return ref.watch(otaAndRemoteConfigServiceProvider).syncSilently();
});

