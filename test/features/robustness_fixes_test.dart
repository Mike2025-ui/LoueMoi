import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/services/notification_router.dart';
import 'package:louemoi/features/agents/models/agent_search_result.dart';
import 'package:louemoi/features/bailleurs/models/bailleur_search_result.dart';
import 'package:louemoi/features/notifications/models/app_notification.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/reviews/models/review.dart';

void main() {
  group('Robustesse BailleurSearchResult & AgentSearchResult', () {
    test('BailleurSearchResult résiste aux champs nuls de DRF', () {
      final json = <String, dynamic>{
        'id': null,
        'first_name': null,
        'last_name': null,
        'photo': null,
        'phone': null,
      };
      final result = BailleurSearchResult.fromJson(json);
      expect(result.id, '');
      expect(result.firstName, '');
      expect(result.lastName, '');
      expect(result.fullName, '');
      expect(result.phone, '');
    });

    test('AgentSearchResult résiste aux drapeaux booléens entiers et notes chaînes', () {
      final json = <String, dynamic>{
        'id': 42,
        'first_name': null,
        'last_name': null,
        'is_verified': 1,
        'rating': '4.8',
        'agency_name': null,
        'description': null,
        'phone': '+22501020304',
      };
      final result = AgentSearchResult.fromJson(json);
      expect(result.id, '42');
      expect(result.firstName, '');
      expect(result.isVerified, isTrue);
      expect(result.rating, 4.8);
      expect(result.agencyName, '');
    });
  });

  group('Robustesse Reviews & Notifications', () {
    test('Review résiste aux IDs nuls et notes en chaîne', () {
      final json = <String, dynamic>{
        'id': null,
        'property_id': 101,
        'user_id': null,
        'user_name': null,
        'rating': '5',
        'comment': null,
        'created_at': null,
      };
      final review = Review.fromJson(json);
      expect(review.id, '');
      expect(review.propertyId, '101');
      expect(review.rating, 5.0);
      expect(review.userName, 'Utilisateur');
      expect(review.comment, '');
      expect(review.createdAt, isA<DateTime>());
    });

    test('AppNotification résiste aux champs nuls, booléens entiers et payloads mixtes', () {
      final json = <String, dynamic>{
        'id': null,
        'title': null,
        'message': 'Votre réservation a été confirmée',
        'type': 'reservation_confirmed',
        'data': {'reservation_id': 12},
        'is_read': 1,
      };
      final notif = AppNotification.fromJson(json);
      expect(notif.id, '');
      expect(notif.title, '');
      expect(notif.message, 'Votre réservation a été confirmée');
      expect(notif.type, NotificationType.reservation);
      expect(notif.isRead, isTrue);
      expect(notif.data['reservation_id'], 12);
    });

    test('NotificationRouter gère les chaînes vides sans produire de route invalide', () {
      const router = NotificationRouter();
      expect(router.resolvePath('new_message', {'conversation_id': ''}), isNull);
      expect(router.resolvePath('new_message', {'conversation_id': '   '}), isNull);
      expect(router.resolvePath('new_message', {'conversation_id': 'abc'}), '/messages/abc');

      expect(router.resolvePath('property_available', {'property_id': ''}), isNull);
      expect(router.resolvePath('property_available', {'property_id': '456'}), '/property/456');
    });
  });

  group('Property toCreatePayload', () {
    test('toCreatePayload omet les champs lecture-seule du serveur et l id draft', () {
      final now = DateTime.now();
      final draft = Property(
        id: 'draft',
        title: 'Superbe Villa',
        description: 'Piscine et jardin',
        type: PropertyType.logement,
        category: 'Villa',
        transactionType: TransactionType.location,
        price: 350000,
        deposit: 700000,
        advance: 700000,
        city: 'Abidjan',
        commune: 'Cocody',
        district: 'Angré',
        address: 'Rue L12',
        status: PropertyStatus.disponible,
        images: const [],
        coverImage: '',
        features: const ['3 chambre(s)'],
        amenities: const ['Piscine'],
        agent: const Agent.empty(),
        createdAt: now,
        updatedAt: now,
      );

      final payload = draft.toCreatePayload();
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('agent'), isFalse);
      expect(payload.containsKey('created_at'), isFalse);
      expect(payload.containsKey('updated_at'), isFalse);
      expect(payload.containsKey('views_count'), isFalse);
      expect(payload['title'], 'Superbe Villa');
      expect(payload['price'], 350000);
      expect(payload['deposit'], 700000);
      expect(payload['advance'], 700000);
    });
  });
}
