import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/utils/geo.dart';

void main() {
  test('haversineKm returns 0 for identical points', () {
    expect(haversineKm(5.359951, -4.008256, 5.359951, -4.008256), closeTo(0, 0.0001));
  });

  test('haversineKm matches the real-world distance between two Abidjan communes', () {
    // Cocody Angré -> Yopougon, environ 11 km (même paire de points utilisée
    // côté Django dans properties/tests.py::PropertyNearbyTests).
    final distance = haversineKm(5.359951, -4.008256, 5.32, -4.10);
    expect(distance, closeTo(11.086, 0.1));
  });

  test('haversineKm is symmetric', () {
    final a = haversineKm(5.359951, -4.008256, 5.32, -4.10);
    final b = haversineKm(5.32, -4.10, 5.359951, -4.008256);
    expect(a, closeTo(b, 0.0001));
  });

  group('normalizeCoordinate', () {
    test('returns null for null', () {
      expect(normalizeCoordinate(null), isNull);
    });

    test('keeps a value that already has 6 decimals or fewer', () {
      expect(normalizeCoordinate(5.35541), 5.35541);
    });

    // Reproduit le bug réel observé sur téléphone : Geolocator/flutter_map
    // renvoient des doubles avec 15+ décimales à cause de l'arithmétique
    // flottante, ce que Django (DecimalField decimal_places=6) rejette avec
    // "Assurez-vous qu'il n'y ait pas plus de 6 chiffres après la virgule."
    test('rounds a float-precision artifact to 6 decimals', () {
      expect(normalizeCoordinate(5.355410123456), 5.35541);
      // Le 7e chiffre (9) arrondit le 6e vers le haut : 991310987654 -> 991311.
      expect(normalizeCoordinate(-3.991310987654), -3.991311);
    });

    test('handles a long trailing-zero artifact', () {
      expect(normalizeCoordinate(5.355410000000001), 5.35541);
    });
  });
}
