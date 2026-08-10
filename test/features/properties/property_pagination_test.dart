import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/filters/models/filter_params.dart';

void main() {
  group('MockPropertyRepository pagination', () {
    test('a single page of mock data reports no next page', () async {
      final repository = MockPropertyRepository();
      final page = await repository.fetchProperties(
        filters: const FilterParams(
          transactionType: TransactionType.location,
          propertyType: PropertyType.logement,
        ),
      );

      expect(page.hasMore, isFalse);
      expect(page.results.length, page.count);
    });

    test('requesting a page beyond the data returns an empty page', () async {
      final repository = MockPropertyRepository();
      final page = await repository.fetchProperties(page: 99);

      expect(page.results, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });
}
