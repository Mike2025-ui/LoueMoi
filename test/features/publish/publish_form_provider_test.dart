import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/publish/providers/publish_form_provider.dart';

Property _property({
  required TransactionType transactionType,
  double? deposit,
  double? advance,
}) {
  final now = DateTime(2026, 1, 1);
  return Property(
    id: '1',
    title: 'Bien existant',
    description: 'Une description',
    type: PropertyType.logement,
    category: 'Villa',
    transactionType: transactionType,
    price: 150000,
    deposit: deposit,
    advance: advance,
    city: 'Abidjan',
    commune: 'Cocody',
    district: 'Vallon',
    address: '',
    status: PropertyStatus.disponible,
    images: const ['http://x/1.jpg', 'http://x/2.jpg'],
    coverImage: 'http://x/1.jpg',
    features: const ['3 chambre(s)'],
    amenities: const ['Eau', 'Parking'],
    agent: const Agent(
      id: '1',
      firstName: 'Agent',
      lastName: 'Test',
      phone: '0700000000',
      whatsapp: '0700000000',
    ),
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('characteristicsOptionsFor', () {
    test('offers logement-specific options', () {
      final options = characteristicsOptionsFor(PropertyType.logement);
      expect(options, contains('Salon'));
      expect(options, contains('Climatisation'));
    });

    test('offers terrain-specific options, distinct from logement', () {
      final options = characteristicsOptionsFor(PropertyType.terrain);
      expect(options, contains('Document disponible'));
      expect(options, isNot(contains('Salon')));
    });

    test('offers magasin-specific options', () {
      final options = characteristicsOptionsFor(PropertyType.magasin);
      expect(options, contains('Sanitaires'));
    });
  });

  group('PublishFormState.fromProperty', () {
    test('prefills the sale price field for a vente property', () {
      final state = PublishFormState.fromProperty(
        _property(transactionType: TransactionType.vente),
      );

      expect(state.price, '150000');
      expect(state.rent, '');
    });

    test('prefills rent/deposit/advance for a location property', () {
      final state = PublishFormState.fromProperty(
        _property(transactionType: TransactionType.location, deposit: 50000, advance: 25000),
      );

      expect(state.rent, '150000');
      expect(state.deposit, '50000');
      expect(state.advance, '25000');
      expect(state.price, '');
    });

    test('carries over existing images and merges features/amenities into characteristics', () {
      final state = PublishFormState.fromProperty(
        _property(transactionType: TransactionType.location),
      );

      expect(state.existingImages, ['http://x/1.jpg', 'http://x/2.jpg']);
      expect(state.characteristics, containsAll(['3 chambre(s)', 'Eau', 'Parking']));
      expect(state.newImages, isEmpty);
    });
  });

  group('PublishFormState.copyWith', () {
    test('preserves unrelated fields when updating one field', () {
      const state = PublishFormState(title: 'Titre', commune: 'Cocody');
      final updated = state.copyWith(title: 'Nouveau titre');

      expect(updated.title, 'Nouveau titre');
      expect(updated.commune, 'Cocody');
    });
  });

  test('hasAtLeastOnePhoto is false with no images and true once one is present', () {
    const empty = PublishFormState();
    expect(empty.hasAtLeastOnePhoto, isFalse);

    final withExisting = empty.copyWith(existingImages: const ['http://x/1.jpg']);
    expect(withExisting.hasAtLeastOnePhoto, isTrue);
  });

  group('PublishFormState location', () {
    test('hasLocation is false until both latitude and longitude are set', () {
      const empty = PublishFormState();
      expect(empty.hasLocation, isFalse);

      final withPosition = empty.copyWith(latitude: 5.35, longitude: -4.0);
      expect(withPosition.hasLocation, isTrue);
    });

    test('fromProperty seeds latitude/longitude when the property already has a position', () {
      final state = PublishFormState.fromProperty(
        _property(transactionType: TransactionType.location).copyWith(
          latitude: 5.359951,
          longitude: -4.008256,
        ),
      );

      expect(state.hasLocation, isTrue);
      expect(state.latitude, 5.359951);
      expect(state.longitude, -4.008256);
    });

    test('fromProperty leaves latitude/longitude null for a property without a position', () {
      final state = PublishFormState.fromProperty(
        _property(transactionType: TransactionType.location),
      );

      expect(state.hasLocation, isFalse);
    });
  });
}
