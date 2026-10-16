import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/gallery/screens/gallery_screen.dart';

void main() {
  group('buildGallerySections', () {
    test('retourne une liste vide si aucune image', () {
      final sections = buildGallerySections([]);
      expect(sections, isEmpty);
    });

    test('catégorise les images selon les préfixes sans duplication', () {
      final images = [
        'https://site.com/media/cat_couverture_main.jpg',
        'https://site.com/media/cat_chambre_bed1.jpg',
        'https://site.com/media/cat_chambre_bed2.jpg',
        'https://site.com/media/cat_salon_living.jpg',
      ];

      final sections = buildGallerySections(images);

      expect(sections.length, 3);
      expect(sections[0].title, 'Couverture');
      expect(sections[0].images, ['https://site.com/media/cat_couverture_main.jpg']);

      expect(sections[1].title, 'Chambre(s)');
      expect(sections[1].images, [
        'https://site.com/media/cat_chambre_bed1.jpg',
        'https://site.com/media/cat_chambre_bed2.jpg',
      ]);

      expect(sections[2].title, 'Salon & Terrasse');
      expect(sections[2].images, ['https://site.com/media/cat_salon_living.jpg']);

      // Vérifie qu'aucune image n'est dupliquée entre les sections
      final allImages = sections.expand((s) => s.images).toList();
      expect(allImages.length, 4);
      expect(allImages.toSet().length, 4);
    });

    test('omet les catégories qui n ont aucune photo sélectionnée', () {
      final images = [
        'https://site.com/media/cat_couverture_p1.jpg',
        'https://site.com/media/cat_chambre_c1.jpg',
      ];

      final sections = buildGallerySections(images);

      expect(sections.length, 2);
      expect(sections.map((s) => s.title).toList(), ['Couverture', 'Chambre(s)']);
      // Cuisine, Salon, Salle de bain ne doivent pas apparaître
      expect(sections.any((s) => s.title.contains('Salon')), isFalse);
      expect(sections.any((s) => s.title.contains('Cuisine')), isFalse);
      expect(sections.any((s) => s.title.contains('Salle')), isFalse);
    });

    test('gère les photos existantes sans tag sans duplication', () {
      final images = [
        'https://site.com/media/img1.jpg',
        'https://site.com/media/img2.jpg',
        'https://site.com/media/img3.jpg',
      ];

      final sections = buildGallerySections(images);

      expect(sections.length, 2);
      expect(sections[0].title, 'Couverture');
      expect(sections[0].images, ['https://site.com/media/img1.jpg']);
      expect(sections[1].title, 'Chambre(s)');
      expect(sections[1].images, [
        'https://site.com/media/img2.jpg',
        'https://site.com/media/img3.jpg',
      ]);

      final allImages = sections.expand((s) => s.images).toList();
      expect(allImages.length, 3);
      expect(allImages.toSet().length, 3);
    });
  });
}

