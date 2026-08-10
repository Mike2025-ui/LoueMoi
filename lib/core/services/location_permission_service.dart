import 'package:geolocator/geolocator.dart';

enum LocationResultStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

/// Résultat d'une tentative de géolocalisation — jamais d'exception non
/// gérée qui remonterait jusqu'à l'UI : tous les cas d'échec (permission
/// refusée, GPS désactivé, timeout...) sont représentés explicitement, avec
/// un message déjà en français, prêt à afficher.
class LocationResult {
  const LocationResult.success({required this.latitude, required this.longitude})
      : status = LocationResultStatus.success,
        message = null;

  const LocationResult.failure(this.status, this.message)
      : latitude = null,
        longitude = null;

  final LocationResultStatus status;
  final double? latitude;
  final double? longitude;
  final String? message;

  bool get isSuccess => status == LocationResultStatus.success;
}

/// Enveloppe geolocator : demande la permission puis la position courante,
/// sans jamais faire planter l'app — chaque cas (refusée, refusée
/// définitivement, GPS désactivé, erreur) est capturé et traduit en
/// [LocationResult].
class LocationPermissionService {
  const LocationPermissionService();

  Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult.failure(
          LocationResultStatus.serviceDisabled,
          'Activez la localisation dans les réglages de votre téléphone.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationResult.failure(
          LocationResultStatus.permissionDenied,
          "Autorisez l'accès à la position pour utiliser cette fonctionnalité.",
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(
          LocationResultStatus.permissionDeniedForever,
          "L'accès à la position est bloqué. Autorisez-le depuis les réglages de l'application.",
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationResult.success(latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return const LocationResult.failure(
        LocationResultStatus.error,
        "Impossible d'obtenir votre position pour le moment.",
      );
    }
  }
}
