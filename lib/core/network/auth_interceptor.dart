import 'package:dio/dio.dart';
import '../services/auth_storage.dart';
import 'api_endpoints.dart';

/// Ajoute automatiquement `Authorization: Bearer <access_token>`, et sur une
/// réponse 401 tente un refresh via le refresh token avant de rejouer la
/// requête d'origine — une seule fois par requête, pour éviter toute boucle
/// infinie si le refresh échoue aussi.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._authStorage, this._dio, {this.onSessionExpired});

  final AuthStorage _authStorage;
  final Dio _dio;

  /// Appelé quand le refresh échoue définitivement (déconnexion forcée).
  final void Function()? onSessionExpired;

  Future<String?>? _refreshInFlight;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _authStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final isAuthEndpoint = err.requestOptions.path.contains('/auth/');
    final alreadyRetried = err.requestOptions.extra['retried'] == true;

    if (err.response?.statusCode != 401 || isAuthEndpoint || alreadyRetried) {
      handler.next(err);
      return;
    }

    final newAccessToken = await _refreshAccessToken();
    if (newAccessToken == null) {
      await _authStorage.clearTokens();
      onSessionExpired?.call();
      handler.next(err);
      return;
    }

    try {
      final retryOptions = err.requestOptions;
      retryOptions.extra['retried'] = true;
      retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
      final response = await _dio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Coalesce les refresh concurrents (plusieurs requêtes en 401 en même
  /// temps ne déclenchent qu'un seul appel réseau de refresh).
  Future<String?> _refreshAccessToken() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _authStorage.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      // Dio "nu", sans intercepteur, pour ne pas redéclencher ce même flux.
      final rawDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));
      final response = await rawDio.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        data: {'refresh': refreshToken},
      );
      final newAccess = response.data?['access'] as String?;
      if (newAccess == null) return null;
      final newRefresh = response.data?['refresh'] as String? ?? refreshToken;
      await _authStorage.saveTokens(access: newAccess, refresh: newRefresh);
      return newAccess;
    } on DioException {
      return null;
    }
  }
}
