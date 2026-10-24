import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/network_providers.dart';

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = PresenceService(apiClient);
  ref.onDispose(() => service.dispose());
  return service;
});

class PresenceService {
  PresenceService(this._apiClient);

  final ApiClient _apiClient;
  Timer? _heartbeatTimer;
  bool _isOnline = false;

  void start() {
    if (Env.useMockData) return;
    pingOnline();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      pingOnline();
    });
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_isOnline) {
      pingOffline();
    }
  }

  Future<void> pingOnline() async {
    if (Env.useMockData) return;
    try {
      await _apiClient.post(
        ApiEndpoints.userPresence,
        data: {'status': 'online'},
      );
      _isOnline = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Presence] Ping online error: $e');
    }
  }

  Future<void> pingOffline() async {
    if (Env.useMockData) return;
    try {
      await _apiClient.post(
        ApiEndpoints.userPresence,
        data: {'status': 'offline'},
      );
      _isOnline = false;
    } catch (e) {
      if (kDebugMode) debugPrint('[Presence] Ping offline error: $e');
    }
  }

  void dispose() {
    stop();
  }
}
