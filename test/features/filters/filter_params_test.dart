import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/filters/models/filter_params.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';

void main() {
  group('FilterParams.copyWith', () {
    test('defaults to Location and Logement', () {
      const params = FilterParams();
      expect(params.transactionType, TransactionType.location);
      expect(params.propertyType, PropertyType.logement);
    });

    test('switching to Terrain does not keep a logement category', () {
      const params = FilterParams(category: 'Villa');
      final updated = params.copyWith(propertyType: PropertyType.terrain, category: 'Terrain');
      expect(updated.propertyType, PropertyType.terrain);
      expect(updated.category, 'Terrain');
    });

    test('preserves unrelated fields when updating one field', () {
      const params = FilterParams(commune: 'Cocody', district: 'Vallon');
      final updated = params.copyWith(isFuture: true);
      expect(updated.commune, 'Cocody');
      expect(updated.district, 'Vallon');
      expect(updated.isFuture, isTrue);
    });
  });
}
