import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';

Property _buildProperty({
  double price = 450000,
  double? deposit = 1230000,
  double? advance = 300000,
  bool isFavorite = false,
  PropertyStatus status = PropertyStatus.disponible,
}) {
  return Property(
    id: '1',
    title: 'Appartement meublé',
    description: 'desc',
    type: PropertyType.logement,
    category: 'Appartement meublé',
    transactionType: TransactionType.location,
    price: price,
    deposit: deposit,
    advance: advance,
    city: 'Abidjan',
    commune: 'Cocody',
    district: 'Vallon',
    address: 'Cocody, Vallon',
    status: status,
    isFavorite: isFavorite,
    images: const ['a.jpg'],
    coverImage: 'a.jpg',
    features: const ['Douche'],
    amenities: const ['Eau'],
    agent: const Agent(
      id: 'a1',
      firstName: 'Mme Kouakou',
      lastName: 'Marie Therese Ange',
      phone: '0700000000',
      whatsapp: '0700000000',
    ),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('Property.reservationTotal', () {
    test('sums price + deposit + advance', () {
      final property = _buildProperty(price: 450000, deposit: 1230000, advance: 300000);
      expect(property.reservationTotal, 1980000);
    });

    test('treats missing deposit/advance as zero', () {
      final property = _buildProperty(price: 65000, deposit: null, advance: null);
      expect(property.reservationTotal, 65000);
    });
  });

  group('Property.isOccupee', () {
    test('is true only when status is occupee', () {
      final occupied = _buildProperty(status: PropertyStatus.occupee);
      final available = _buildProperty(status: PropertyStatus.disponible);
      expect(occupied.isOccupee, isTrue);
      expect(available.isOccupee, isFalse);
    });
  });

  group('Property.copyWith', () {
    test('toggles isFavorite without mutating other fields', () {
      final property = _buildProperty(isFavorite: false);
      final updated = property.copyWith(isFavorite: true);
      expect(updated.isFavorite, isTrue);
      expect(updated.id, property.id);
      expect(updated.price, property.price);
    });
  });
}
