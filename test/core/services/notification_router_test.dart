import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/services/notification_router.dart';

void main() {
  const router = NotificationRouter();

  test('new_message navigue vers la conversation', () {
    expect(
      router.resolvePath('new_message', {'conversation_id': '12'}),
      '/messages/12',
    );
  });

  test('new_message sans conversation_id ne navigue nulle part', () {
    expect(router.resolvePath('new_message', {}), isNull);
  });

  for (final type in [
    'reservation_created',
    'reservation_confirmed',
    'reservation_cancelled',
    'new_reservation',
  ]) {
    test('$type navigue vers la liste des réservations', () {
      expect(router.resolvePath(type, {}), '/reservations');
    });
  }

  for (final type in ['property_occupied', 'property_available']) {
    test('$type navigue vers le détail de la propriété', () {
      expect(
        router.resolvePath(type, {'property_id': '7'}),
        '/property/7',
      );
    });

    test('$type sans property_id ne navigue nulle part', () {
      expect(router.resolvePath(type, {}), isNull);
    });
  }

  test('new_review navigue vers le détail de la propriété (pas de route dédiée aux avis)', () {
    // AppRoutes.propertyReviews n'existe plus : ce chemin n'était enregistré
    // dans aucune GoRoute (voir router.dart), donc y naviguer plantait avec
    // une "no matching route". Les avis s'affichent dans l'onglet "Avis" de
    // PropertyDetailScreen, jamais un écran séparé.
    expect(
      router.resolvePath('new_review', {'property_id': '7'}),
      '/property/7',
    );
  });

  test('new_review sans property_id ne navigue nulle part', () {
    expect(router.resolvePath('new_review', {}), isNull);
  });

  test('type inconnu ne navigue nulle part', () {
    expect(router.resolvePath('unknown_type', {'property_id': '7'}), isNull);
  });
}
