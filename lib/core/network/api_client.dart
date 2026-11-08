import 'package:dio/dio.dart';
import '../services/auth_storage.dart';
import 'api_endpoints.dart';
import 'api_exceptions.dart';
import 'auth_interceptor.dart';

/// Client HTTP centralisé (Dio). Toute la logique réseau transverse
/// (timeout, token, refresh, erreurs) vit ici — jamais dans les widgets, et
/// jamais dans les repositories (qui ne manipulent que des [ApiException]).
class ApiClient {
  ApiClient(this._authStorage, {void Function()? onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      AuthInterceptor(_authStorage, _dio, onSessionExpired: onSessionExpired),
    );
  }

  final AuthStorage _authStorage;
  late final Dio _dio;
  final Map<String, Future<Response<dynamic>>> _inflightRequests = {};

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query, Options? options}) {
    // Dédoublonnage des requêtes GET identiques en vol : si une requête identique
    // est déjà en cours d'exécution, on partage la même promesse pour économiser
    // la batterie, la bande passante et la charge serveur.
    final key = '$path?${query?.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    if (_inflightRequests.containsKey(key)) {
      return _inflightRequests[key]!.then((res) => res as Response<T>);
    }

    final future = _run(() => _dio.get<T>(path, queryParameters: query, options: options));
    _inflightRequests[key] = future;
    return future.whenComplete(() {
      _inflightRequests.remove(key);
    });
  }

  Future<Response<T>> post<T>(String path, {dynamic data, Options? options}) {
    return _run(() => _dio.post<T>(path, data: data, options: options));
  }

  Future<Response<T>> put<T>(String path, {dynamic data, Options? options}) {
    return _run(() => _dio.put<T>(path, data: data, options: options));
  }

  Future<Response<T>> patch<T>(String path, {dynamic data, Options? options}) {
    return _run(() => _dio.patch<T>(path, data: data, options: options));
  }

  Future<Response<T>> delete<T>(String path, {dynamic data, Options? options}) {
    return _run(() => _dio.delete<T>(path, data: data, options: options));
  }

  Future<Response<T>> _run<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
