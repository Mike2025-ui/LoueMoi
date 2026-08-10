import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/profile/data/agent_repository.dart';
import 'package:louemoi/features/profile/models/agent_dashboard.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('AgentDashboard.fromJson', () {
    test('parses every real (never hardcoded) stat from the Django response', () {
      final dashboard = AgentDashboard.fromJson({
        'properties_count': 6,
        'available_count': 4,
        'occupied_count': 2,
        'reservations_count': 3,
        'favorites_received': 5,
        'views_count': 128,
        'messages_count': 7,
        'reviews_count': 12,
        'average_rating': 4.6,
      });

      expect(dashboard.propertiesCount, 6);
      expect(dashboard.availableCount, 4);
      expect(dashboard.occupiedCount, 2);
      expect(dashboard.reservationsCount, 3);
      expect(dashboard.favoritesReceived, 5);
      expect(dashboard.viewsCount, 128);
      expect(dashboard.messagesCount, 7);
      expect(dashboard.reviewsCount, 12);
      expect(dashboard.averageRating, 4.6);
    });

    test('defaults missing fields to zero instead of throwing', () {
      final dashboard = AgentDashboard.fromJson(const {});

      expect(dashboard.propertiesCount, 0);
      expect(dashboard.averageRating, 0.0);
    });
  });

  test('ApiAgentRepository.getDashboard calls GET /api/agent/dashboard/', () async {
    final apiClient = MockApiClient();
    final repository = ApiAgentRepository(apiClient);
    when(() => apiClient.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response(
        data: {'properties_count': 1},
        requestOptions: RequestOptions(path: '/'),
      ),
    );

    final dashboard = await repository.getDashboard();

    expect(dashboard.propertiesCount, 1);
    verify(() => apiClient.get<Map<String, dynamic>>('/api/agent/dashboard/')).called(1);
  });
}
