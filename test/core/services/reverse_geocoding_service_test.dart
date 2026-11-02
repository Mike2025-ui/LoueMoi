import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/services/reverse_geocoding_service.dart';

void main() {
  late ReverseGeocodingService service;

  setUp(() {
    service = ReverseGeocodingService();
  });

  group('ReverseGeocodingService offline fallback', () {
    test('resolves Cocody for coordinates near Cocody center', () {
      final commune = service.resolveNearestCommune(5.359951, -3.985000);
      expect(commune, 'Cocody');
    });

    test('resolves Yopougon for coordinates near Yopougon center', () {
      final commune = service.resolveNearestCommune(5.340000, -4.080000);
      expect(commune, 'Yopougon');
    });

    test('resolves Plateau for coordinates near Plateau center', () {
      final commune = service.resolveNearestCommune(5.323000, -4.019000);
      expect(commune, 'Plateau');
    });

    test('resolves Marcory for coordinates near Marcory center', () {
      final commune = service.resolveNearestCommune(5.300000, -3.980000);
      expect(commune, 'Marcory');
    });

    test('returns null when coordinates are far outside Abidjan', () {
      final commune = service.resolveNearestCommune(0.0, 0.0);
      expect(commune, isNull);
    });
  });
}
