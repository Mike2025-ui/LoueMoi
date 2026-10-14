import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Synchronise le token FCM de l'appareil avec Django — jamais de logique
/// Firebase ici (voir core/services/fcm_service.dart pour ça).
abstract class DeviceTokenRepository {
  Future<void> register(String token, String platform);
  Future<void> deactivate(String token);
}

class ApiDeviceTokenRepository implements DeviceTokenRepository {
  ApiDeviceTokenRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<void> register(String token, String platform) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.devices,
      data: {'token': token, 'platform': platform},
    );
  }

  @override
  Future<void> deactivate(String token) async {
    await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.devicesDeactivate,
      data: {'token': token},
    );
  }
}

/// USE_MOCK_DATA=true : aucun appel Django réel, comme pour tous les autres
/// repositories mock.
class MockDeviceTokenRepository implements DeviceTokenRepository {
  @override
  Future<void> register(String token, String platform) async {}

  @override
  Future<void> deactivate(String token) async {}
}
