import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/notifications/data/api_notification_repository.dart';
import 'package:louemoi/features/notifications/models/app_notification.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

void main() {
  late MockApiClient apiClient;
  late ApiNotificationRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ApiNotificationRepository(apiClient);
  });

  test('fetchNotifications excludes new_message notifications', () async {
    when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
        .thenAnswer((_) async => _fakeResponse({
              'count': 3,
              'results': [
                {
                  'id': 1,
                  'title': 'Réservation',
                  'body': 'Nouvelle réservation',
                  'type': 'new_reservation',
                  'is_read': false,
                  'created_at': '2026-01-01T00:00:00Z',
                  'data': {},
                },
                {
                  'id': 2,
                  'title': 'Message',
                  'body': 'Salut',
                  'type': 'new_message',
                  'is_read': false,
                  'created_at': '2026-01-01T00:00:00Z',
                  'data': {'conversation_id': '1'},
                },
                {
                  'id': 3,
                  'title': 'Favori',
                  'body': 'Bien aimé',
                  'type': 'new_favorite',
                  'is_read': true,
                  'created_at': '2026-01-01T00:00:00Z',
                  'data': {},
                },
              ],
            }));

    final notifications = await repository.fetchNotifications();
    expect(notifications.length, 2);
    expect(notifications.any((n) => n.rawType == 'new_message'), isFalse);
    expect(notifications.any((n) => n.type == NotificationType.message), isFalse);
  });

  test('fetchUnreadCount calculates unread count strictly excluding new_message', () async {
    when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
        .thenAnswer((_) async => _fakeResponse({
              'count': 3,
              'results': [
                {
                  'id': 1,
                  'title': 'Réservation',
                  'body': 'Nouvelle réservation',
                  'type': 'new_reservation',
                  'is_read': false,
                  'created_at': '2026-01-01T00:00:00Z',
                  'data': {},
                },
                {
                  'id': 2,
                  'title': 'Message',
                  'body': 'Nouveau message reçu',
                  'type': 'new_message',
                  'is_read': false, // non lu, mais NE DOIT PAS être compté par la cloche !
                  'created_at': '2026-01-01T00:00:00Z',
                  'data': {},
                },
                {
                  'id': 3,
                  'title': 'Bien disponible',
                  'body': 'Nouveau bien',
                  'type': 'property_available',
                  'is_read': true,
                  'created_at': '2026-01-01T00:00:00Z',
                  'data': {},
                },
              ],
            }));

    final unreadCount = await repository.fetchUnreadCount();
    expect(unreadCount, 1, reason: 'Seule la notification réservation est non lue et non un message');
  });
}

