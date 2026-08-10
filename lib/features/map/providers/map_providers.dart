import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../properties/models/property.dart';
import '../../properties/providers/property_providers.dart';

/// Rayon de recherche sélectionné sur PropertyMapScreen (km).
final mapRadiusKmProvider = StateProvider.autoDispose<double>((ref) => 5);

/// Centre de la recherche à proximité — position GPS de l'utilisateur si
/// disponible, sinon un centre par défaut (voir PropertyMapScreen). Null
/// tant que la géolocalisation initiale n'a pas résolu.
final mapCenterProvider = StateProvider.autoDispose<LatLng?>((ref) => null);

/// GET /api/properties/nearby/ (ou équivalent Haversine en mock) — recalculé
/// à chaque changement de centre ou de rayon, jamais en filtrant
/// fetchProperties() côté Flutter.
final nearbyPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final center = ref.watch(mapCenterProvider);
  if (center == null) return const [];
  final radiusKm = ref.watch(mapRadiusKmProvider);
  final repository = ref.watch(propertyRepositoryProvider);
  return repository.getNearbyProperties(
    latitude: center.latitude,
    longitude: center.longitude,
    radiusKm: radiusKm,
  );
});
