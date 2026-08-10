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
}
