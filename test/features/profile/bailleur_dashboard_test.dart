import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/profile/data/bailleur_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  test('ApiBailleurRepository.getDashboard calls GET /api/bailleur/dashboard/', () async {
    final apiClient = MockApiClient();
    final repository = ApiBailleurRepository(apiClient);
    when(() => apiClient.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response(
        data: {'properties_count': 3, 'average_rating': 4.1},
        requestOptions: RequestOptions(path: '/'),
      ),
    );

    final dashboard = await repository.getDashboard();

    expect(dashboard.propertiesCount, 3);
    expect(dashboard.averageRating, 4.1);
    verify(() => apiClient.get<Map<String, dynamic>>('/api/bailleur/dashboard/')).called(1);
  });

  test('MockBailleurRepository starts at zero (no demo bailleur listings)', () async {
    final dashboard = await MockBailleurRepository().getDashboard();
    expect(dashboard.propertiesCount, 0);
    expect(dashboard.averageRating, 0);
  });
}
