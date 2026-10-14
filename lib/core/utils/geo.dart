import 'dart:math';

const double _earthRadiusKm = 6371.0;

/// Distance en kilomètres entre deux points (formule de Haversine),
/// identique à celle utilisée côté Django pour /api/properties/nearby/.
/// Utilisée uniquement en mode mock (MockPropertyRepository) : en mode API,
/// la distance est toujours calculée côté serveur, jamais recalculée ici.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * asin(sqrt(a));
  return _earthRadiusKm * c;
}

double _toRadians(double degrees) => degrees * pi / 180.0;

/// Arrondit une coordonnée GPS à 6 décimales — même précision que
/// `Property.latitude`/`longitude` côté Django (`DecimalField(decimal_places=6)`).
/// Les valeurs venant du GPS (Geolocator) ou d'un tap sur la carte
/// (flutter_map, conversion pixel -> LatLng) ont couramment 15+ décimales
/// à cause de l'arithmétique flottante (ex: 5.355410000000004), ce que
/// Django rejette avec "Assurez-vous qu'il n'y ait pas plus de 6 chiffres
/// après la virgule.". À appliquer juste avant toute sérialisation
/// POST/PATCH vers l'API, jamais sur la valeur affichée à l'utilisateur.
double? normalizeCoordinate(double? value) {
  if (value == null) return null;
  return double.parse(value.toStringAsFixed(6));
}
