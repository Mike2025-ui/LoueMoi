import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';

void main() {
  group('Property.fromJson Resilience Tests', () {
    test('handles null status gracefully without crashing', () {
      final json = <String, dynamic>{
        'id': 'prop-1',
        'title': 'Studio chic',
        'price': '75000',
        'status': null,
      };

      final property = Property.fromJson(json);
      expect(property.id, equals('prop-1'));
      expect(property.title, equals('Studio chic'));
      expect(property.price, equals(75000.0));
      expect(property.status, equals(PropertyStatus.disponible));
    });

    test('handles boolean flags provided as integer (0 or 1)', () {
      final json = <String, dynamic>{
        'id': 123,
        'title': 'Appartement plateau',
        'is_future': 1,
        'is_favorite': 0,
        'owner_has_active_subscription': 1,
      };

      final property = Property.fromJson(json);
      expect(property.id, equals('123'));
      expect(property.isFuture, isTrue);
      expect(property.isFavorite, isFalse);
      expect(property.ownerHasActiveSubscription, isTrue);
    });

    test('handles views_count and favorites_count provided as doubles or strings', () {
      final json = <String, dynamic>{
        'id': 'p2',
        'views_count': 42.0,
        'favorites_count': '15',
      };

      final property = Property.fromJson(json);
      expect(property.viewsCount, equals(42));
      expect(property.favoritesCount, equals(15));
    });

    test('falls back coverImage to first image when cover_image is empty or null', () {
      final json = <String, dynamic>{
        'id': 'p3',
        'cover_image': null,
        'images': ['https://example.com/img1.jpg', 'https://example.com/img2.jpg'],
      };

      final property = Property.fromJson(json);
      expect(property.coverImage, equals('https://example.com/img1.jpg'));
    });

    test('handles untyped or missing agent map without throwing TypeError', () {
      final dynamic untypedAgent = <dynamic, dynamic>{
        'id': 456,
        'first_name': 'Amadou',
        'is_verified': 1,
      };

      final json = <String, dynamic>{
        'id': 'p4',
        'agent': untypedAgent,
      };

      final property = Property.fromJson(json);
      expect(property.agent.id, equals('456'));
      expect(property.agent.firstName, equals('Amadou'));
      expect(property.agent.isVerified, isTrue);
    });

    test('handles missing or null agent safely with default Agent.empty', () {
      final json = <String, dynamic>{
        'id': 'p5',
        'agent': null,
      };

      final property = Property.fromJson(json);
      expect(property.agent.id, isEmpty);
      expect(property.agent.firstName, equals('LoueMoi'));
    });

    test('formats locationLabel cleanly without stray commas', () {
      final propFull = Property.fromJson({
        'id': '1',
        'commune': 'Cocody',
        'district': 'Angré',
      });
      expect(propFull.locationLabel, equals('Cocody, Angré'));

      final propOnlyCommune = Property.fromJson({
        'id': '2',
        'commune': 'Yopougon',
        'district': '',
      });
      expect(propOnlyCommune.locationLabel, equals('Yopougon'));

      final propOnlyDistrict = Property.fromJson({
        'id': '3',
        'commune': '',
        'district': 'Zone 4',
      });
      expect(propOnlyDistrict.locationLabel, equals('Zone 4'));

      final propNeither = Property.fromJson({
        'id': '4',
        'commune': '',
        'district': '',
        'city': 'Abidjan',
      });
      expect(propNeither.locationLabel, equals('Abidjan'));
    });
  });

  group('Agent.fromJson Resilience Tests', () {
    test('handles integer boolean flags and string numbers', () {
      final json = <String, dynamic>{
        'id': 99,
        'first_name': 'Koffi',
        'is_verified': 1,
        'has_active_subscription': 0,
        'rating': '4.8',
      };

      final agent = Agent.fromJson(json);
      expect(agent.id, equals('99'));
      expect(agent.firstName, equals('Koffi'));
      expect(agent.isVerified, isTrue);
      expect(agent.hasActiveSubscription, isFalse);
      expect(agent.rating, equals(4.8));
    });
  });
}

