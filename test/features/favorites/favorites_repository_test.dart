import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';

void main() {
  group('MockPropertyRepository favorites', () {
    test('toggleFavorite flips isFavorite and persists across fetches', () async {
      final repository = MockPropertyRepository();
      final page = await repository.fetchProperties();
      final target = page.results.first;
      expect(target.isFavorite, isFalse);

      final updated = await repository.toggleFavorite(target.id);
      expect(updated.isFavorite, isTrue);

      final favorites = await repository.fetchFavorites();
      expect(favorites.map((p) => p.id), contains(target.id));

      final toggledBack = await repository.toggleFavorite(target.id);
      expect(toggledBack.isFavorite, isFalse);

      final favoritesAfter = await repository.fetchFavorites();
      expect(favoritesAfter.map((p) => p.id), isNot(contains(target.id)));
    });
  });
}
