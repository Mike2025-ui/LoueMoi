import 'package:dio/dio.dart';
import '../utils/geo.dart';

/// Résultat d'un géocodage inverse (coordonnées GPS -> adresse / commune / quartier).
class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    this.city,
    this.commune,
    this.district,
    this.address,
  });

  final String? city;
  final String? commune;
  final String? district;
  final String? address;

  bool get hasData =>
      (commune != null && commune!.isNotEmpty) ||
      (district != null && district!.isNotEmpty);
}

/// Service de géocodage inverse : traduit les coordonnées GPS en ville, commune
/// et quartier. Combine un appel réseau OpenStreetMap Nominatim (avec timeout
/// court) et un résolveur hors-ligne pour les communes principales d'Abidjan et
/// de Côte d'Ivoire.
class ReverseGeocodingService {
  ReverseGeocodingService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  // Centres de référence des communes principales pour le repli hors-ligne
  static const _communesRef = <String, (double, double)>{
    'Cocody': (5.359951, -3.985000),
    'Plateau': (5.323000, -4.019000),
    'Yopougon': (5.340000, -4.080000),
    'Marcory': (5.300000, -3.980000),
    'Koumassi': (5.290000, -3.950000),
    'Treichville': (5.305000, -4.010000),
    'Port-Bouët': (5.250000, -3.930000),
    'Adjamé': (5.360000, -4.030000),
    'Abobo': (5.420000, -4.020000),
    'Attécoubé': (5.330000, -4.040000),
    'Bingerville': (5.355000, -3.890000),
    'Songon': (5.320000, -4.250000),
    'Anyama': (5.490000, -4.050000),
    'Grand-Bassam': (5.210000, -3.740000),
  };

  /// Résout la commune la plus proche à partir des coordonnées GPS (hors-ligne).
  String? resolveNearestCommune(double lat, double lng) {
    String? nearest;
    double minDistance = double.infinity;

    for (final entry in _communesRef.entries) {
      final (refLat, refLng) = entry.value;
      final dist = haversineKm(lat, lng, refLat, refLng);
      if (dist < minDistance && dist <= 7.0) {
        // Dans un rayon maximal de 7 km du centre de la commune
        minDistance = dist;
        nearest = entry.key;
      }
    }
    return nearest;
  }

  /// Tente de résoudre l'adresse complète depuis les coordonnées GPS.
  /// Ne lève jamais d'exception : en cas de coupure réseau ou de timeout,
  /// utilise le résolveur local.
  Future<ReverseGeocodeResult> reverseGeocode(double lat, double lng) async {
    String? detectedCity = 'Abidjan';
    String? detectedCommune;
    String? detectedDistrict;
    String? detectedAddress;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': lat,
          'lon': lng,
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          headers: {'User-Agent': 'LoueMoi/1.0 (contact@louemoi.ci)'},
        ),
      );

      final data = response.data;
      if (data != null) {
        final address = data['address'];
        final displayName = (data['display_name'] as String?) ?? '';

        if (address is Map<String, dynamic>) {
          detectedCity = (address['city'] as String?) ??
              (address['town'] as String?) ??
              (address['state'] as String?) ??
              'Abidjan';

          detectedDistrict = (address['suburb'] as String?) ??
              (address['neighbourhood'] as String?) ??
              (address['quarter'] as String?) ??
              (address['residential'] as String?);

          detectedAddress = (address['road'] as String?) ??
              (address['pedestrian'] as String?);

          // Vérifier si une commune d'Abidjan est mentionnée dans l'adresse ou display_name
          final cityDistrict = address['city_district'] as String?;
          final county = address['county'] as String?;

          for (final c in _communesRef.keys) {
            if (displayName.toLowerCase().contains(c.toLowerCase()) ||
                (cityDistrict != null && cityDistrict.toLowerCase().contains(c.toLowerCase())) ||
                (county != null && county.toLowerCase().contains(c.toLowerCase()))) {
              detectedCommune = c;
              break;
            }
          }
        }
      }
    } catch (_) {
      // Ignorer l'échec réseau, repli local ci-dessous
    }

    // Repli local si la commune n'a pas été identifiée via l'API
    detectedCommune ??= resolveNearestCommune(lat, lng);

    return ReverseGeocodeResult(
      city: detectedCity,
      commune: detectedCommune,
      district: detectedDistrict,
      address: detectedAddress,
    );
  }
}

