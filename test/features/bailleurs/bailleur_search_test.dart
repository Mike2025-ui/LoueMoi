import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/bailleurs/data/bailleur_search_repository.dart';
import 'package:louemoi/features/bailleurs/models/bailleur_search_result.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

Map<String, dynamic> _bailleurJson({String firstName = 'Awa'}) {
  return {
    'id': 9,
    'first_name': firstName,
    'last_name': 'Kone',
    'photo': null,
    'phone': '+2250700000001',
  };
}

void main() {
  group('BailleurSearchResult.fromJson', () {
    test('parses public bailleur fields, never a password/token field', () {
      final bailleur = BailleurSearchResult.fromJson(_bailleurJson());
      expect(bailleur.id, '9');
      expect(bailleur.fullName, 'Awa Kone');
      expect(bailleur.phone, '+2250700000001');
    });

    test('defaults missing optional fields cleanly instead of throwing', () {
      final bailleur = BailleurSearchResult.fromJson({
        'id': 1,
        'first_name': 'A',
        'last_name': 'B',
      });
      expect(bailleur.phone, '');
      expect(bailleur.photo, isNull);
    });
  });

  group('ApiBailleurSearchRepository.searchBailleurs', () {
    late MockApiClient apiClient;
    late ApiBailleurSearchRepository repository;

    setUp(() {
      apiClient = MockApiClient();
      repository = ApiBailleurSearchRepository(apiClient);
    });

    test('calls GET /api/bailleurs/ with the search query', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 1,
                'next': null,
                'previous': null,
                'results': [_bailleurJson()],
              }));

      final results = await repository.searchBailleurs(search: 'Awa');

      expect(results, hasLength(1));
      final call = verify(
        () => apiClient.get<Map<String, dynamic>>(
          captureAny(),
          query: captureAny(named: 'query'),
        ),
      ).captured;
      expect(call.first, '/api/bailleurs/');
      final query = call[1] as Map<String, dynamic>;
      expect(query['search'], 'Awa');
    });

    test('omits the search param entirely when no query is given', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 0,
                'next': null,
                'previous': null,
                'results': [],
              }));

      await repository.searchBailleurs();

      final query = verify(
        () => apiClient.get<Map<String, dynamic>>(any(), query: captureAny(named: 'query')),
      ).captured.single as Map<String, dynamic>;
      expect(query.containsKey('search'), isFalse);
    });
  });

  group('MockBailleurSearchRepository', () {
    test('returns all demo bailleurs when the search is empty', () async {
      final results = await MockBailleurSearchRepository().searchBailleurs();
      expect(results, isNotEmpty);
    });

    test('filters demo bailleurs by name, case-insensitively', () async {
      final results = await MockBailleurSearchRepository().searchBailleurs(search: 'coulibaly');
      expect(results, isNotEmpty);
      expect(results.every((b) => b.fullName.toLowerCase().contains('coulibaly')), isTrue);
    });
  });
}
