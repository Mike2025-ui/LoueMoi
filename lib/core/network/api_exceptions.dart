import 'package:dio/dio.dart';

/// Erreur API normalisée, avec un message déjà prêt pour l'affichage (FR).
/// Toute la couche data doit lever ce type d'exception — jamais un DioException
/// brut — pour que l'UI n'ait jamais besoin de connaître Dio.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.fieldErrors});

  final String message;

  /// Erreurs de validation par champ, si le backend en fournit (400/422).
  final Map<String, List<String>>? fieldErrors;

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException()
      : super('Vérifiez votre connexion internet et réessayez.');
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Session expirée, veuillez vous reconnecter.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'Action non autorisée.']);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Ressource introuvable.']);
}

class ConflictException extends ApiException {
  const ConflictException([super.message = 'Cette action entre en conflit avec l\'existant.']);
}

class ValidationException extends ApiException {
  const ValidationException(super.message, {super.fieldErrors});
}

class ServerException extends ApiException {
  const ServerException([super.message = 'Le serveur rencontre un problème, réessayez plus tard.']);
}

class UnknownApiException extends ApiException {
  const UnknownApiException([super.message = 'Une erreur inattendue est survenue.']);
}

/// Convertit un DioException en [ApiException] exploitable par l'UI.
ApiException mapDioException(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return const NetworkException();
  }

  final response = error.response;
  if (response == null) return const NetworkException();

  final data = response.data;
  final serverMessage = _extractMessage(data);

  return switch (response.statusCode ?? 0) {
    400 || 422 => ValidationException(
        serverMessage ?? 'Certaines informations sont invalides.',
        fieldErrors: _extractFieldErrors(data),
      ),
    401 => UnauthorizedException(serverMessage ?? 'Numéro de téléphone ou mot de passe invalide.'),
    403 => ForbiddenException(serverMessage ?? 'Action non autorisée.'),
    404 => NotFoundException(serverMessage ?? 'Ressource introuvable.'),
    409 => ConflictException(serverMessage ?? 'Cette action entre en conflit avec l\'existant.'),
    429 => const UnknownApiException('Trop de tentatives, veuillez patienter.'),
    >= 500 => const ServerException(),
    _ => UnknownApiException(serverMessage ?? 'Une erreur inattendue est survenue.'),
  };
}

String? _extractMessage(dynamic data) {
  if (data is Map) {
    final detail = data['detail'] ?? data['message'];
    if (detail is String) return detail;
    // DRF renvoie parfois {"field": ["message"]} sans "detail" global.
    for (final value in data.values) {
      if (value is List && value.isNotEmpty && value.first is String) {
        return value.first as String;
      }
    }
  }
  return null;
}

Map<String, List<String>>? _extractFieldErrors(dynamic data) {
  if (data is! Map) return null;
  final errors = <String, List<String>>{};
  for (final entry in data.entries) {
    if (entry.value is List) {
      errors[entry.key.toString()] = (entry.value as List).map((e) => e.toString()).toList();
    }
  }
  return errors.isEmpty ? null : errors;
}
