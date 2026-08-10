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

    test('sets latitude/longitude without affecting other fields', () {
      final property = _buildProperty();
      final updated = property.copyWith(latitude: 5.35, longitude: -4.0);
      expect(updated.latitude, 5.35);
      expect(updated.longitude, -4.0);
      expect(updated.title, property.title);
    });
  });

  group('Property geolocation parsing', () {
    Map<String, dynamic> buildPropertyJson({
      double? latitude,
      double? longitude,
      double? distanceKm,
    }) {
      final json = {
        'id': 1,
        'title': 'Bien geo',
        'description': '',
        'type': 'logement',
        'category': 'Studio',
        'transaction_type': 'location',
        'price': 100000,
        'deposit': null,
        'advance': null,
        'city': 'Abidjan',
        'commune': 'Cocody',
        'district': 'Vallon',
        'address': '',
        'latitude': latitude,
        'longitude': longitude,
        'status': 'disponible',
        'is_future': false,
        'is_favorite': false,
        'images': <String>[],
        'cover_image': '',
        'features': <String>[],
        'amenities': <String>[],
        'agent': {
          'id': 1,
          'first_name': 'Agent',
          'last_name': 'Test',
          'phone': '0700000000',
          'whatsapp': '0700000000',
          'is_verified': true,
          'rating': 4.8,
        },
        'views_count': 0,
        'favorites_count': 0,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };
      if (distanceKm != null) json['distance_km'] = distanceKm;
      return json;
    }

    test('parses latitude/longitude/distance_km when present', () {
      final property = Property.fromJson(buildPropertyJson(latitude: 5.359951, longitude: -4.008256, distanceKm: 2.4));
      expect(property.latitude, 5.359951);
      expect(property.longitude, -4.008256);
      expect(property.distanceKm, 2.4);
    });

    test('a property without coordinates parses cleanly, without crashing', () {
      final property = Property.fromJson(buildPropertyJson());
      expect(property.latitude, isNull);
      expect(property.longitude, isNull);
      expect(property.distanceKm, isNull);
    });

    test('toJson only includes distance_km when it is set', () {
      final withDistance =
          Property.fromJson(buildPropertyJson(latitude: 5.35, longitude: -4.0, distanceKm: 1.2)).toJson();
      final withoutDistance = Property.fromJson(buildPropertyJson()).toJson();

      expect(withDistance.containsKey('distance_km'), isTrue);
      expect(withoutDistance.containsKey('distance_km'), isFalse);
    });
  });
}
