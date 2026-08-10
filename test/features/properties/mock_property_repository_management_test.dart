import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';

void main() {
  late MockPropertyRepository repository;

  setUp(() {
    repository = MockPropertyRepository();
  });

  test('addProperty then updateProperty changes only the requested fields', () async {
    final page = await repository.fetchProperties();
    final existing = page.results.first;

    final updated = await repository.updateProperty(existing.id, {'title': 'Titre modifie'});

    expect(updated.title, 'Titre modifie');
    expect(updated.commune, existing.commune);
  });

  test('deleteProperty removes the property from subsequent fetches', () async {
    final page = await repository.fetchProperties();
    final target = page.results.first;

    await repository.deleteProperty(target.id);

    final remaining = await repository.fetchProperties();
    expect(remaining.results.any((p) => p.id == target.id), isFalse);
  });

  test('uploadImage appends the local file path and sets it as cover when requested', () async {
    final page = await repository.fetchProperties();
    final target = page.results.first;
    const localPath = '/tmp/photo.jpg';

    final updated = await repository.uploadImage(
      target.id,
      XFile(localPath),
      isCover: true,
    );

    expect(updated.images, contains(localPath));
    expect(updated.coverImage, localPath);
  });

  test('deleteImage removes the URL and clears cover if it was the cover image', () async {
    final page = await repository.fetchProperties();
    final target = page.results.first;
    final withImage = await repository.uploadImage(target.id, XFile('/tmp/a.jpg'), isCover: true);

    final updated = await repository.deleteImage(withImage.id, '/tmp/a.jpg');

    expect(updated.images.contains('/tmp/a.jpg'), isFalse);
  });

  test('incrementView increases viewsCount by one', () async {
    final page = await repository.fetchProperties();
    final target = page.results.first;

    final updated = await repository.incrementView(target.id);

    expect(updated.viewsCount, target.viewsCount + 1);
  });

  group('getNearbyProperties (Haversine en Dart, aucun appel réseau)', () {
    // Coordonnées réelles des données mock (mock_properties.dart) : le bien
    // '1' est exactement à l'origine, le bien '8' n'a pas de position.
    const originLat = 5.359951;
    const originLng = -4.008256;

    test('returns properties within the radius, sorted nearest-first', () async {
      final results = await repository.getNearbyProperties(
        latitude: originLat,
        longitude: originLng,
        radiusKm: 5,
      );

      expect(results, isNotEmpty);
      expect(results.first.id, '1');
      expect(results.first.distanceKm, closeTo(0, 0.01));
      for (var i = 1; i < results.length; i++) {
        expect(results[i].distanceKm! >= results[i - 1].distanceKm!, isTrue);
      }
    });

    test('excludes properties without coordinates, never crashes', () async {
      final results = await repository.getNearbyProperties(
        latitude: originLat,
        longitude: originLng,
        radiusKm: 1000,
      );

      expect(results.any((p) => p.id == '8'), isFalse);
    });

    test('a tight radius excludes everything but the origin property', () async {
      final results = await repository.getNearbyProperties(
        latitude: originLat,
        longitude: originLng,
        radiusKm: 0.01,
      );

      expect(results, hasLength(1));
      expect(results.first.id, '1');
    });
  });

  test('updatePropertyLocation sets latitude/longitude on the target property', () async {
    final updated = await repository.updatePropertyLocation('8', 5.4, -4.05);

    expect(updated.latitude, 5.4);
    expect(updated.longitude, -4.05);
  });
}
