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
}
