import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/agents/data/agent_search_repository.dart';
import 'package:louemoi/features/agents/models/agent_search_result.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

Map<String, dynamic> _agentJson({String firstName = 'Kouassi', bool isVerified = false}) {
  return {
    'id': 7,
    'first_name': firstName,
    'last_name': 'Jean',
    'photo': null,
    'phone': '+2250700000000',
    'agency_name': 'ABC Immo',
    'description': 'Spécialiste Cocody',
    'rating': 4.5,
    'is_verified': isVerified,
  };
}

void main() {
  group('AgentSearchResult.fromJson', () {
    test('parses public agent fields, never a password/token field', () {
      final agent = AgentSearchResult.fromJson(_agentJson(isVerified: true));
      expect(agent.id, '7');
      expect(agent.fullName, 'Kouassi Jean');
      expect(agent.agencyName, 'ABC Immo');
      expect(agent.rating, 4.5);
      expect(agent.isVerified, isTrue);
    });

    test('defaults missing optional fields cleanly instead of throwing', () {
      final agent = AgentSearchResult.fromJson({
        'id': 1,
        'first_name': 'A',
        'last_name': 'B',
      });
      expect(agent.phone, '');
      expect(agent.agencyName, '');
      expect(agent.rating, 0);
      expect(agent.isVerified, isFalse);
    });
  });

  group('ApiAgentSearchRepository.searchAgents', () {
    late MockApiClient apiClient;
    late ApiAgentSearchRepository repository;

    setUp(() {
      apiClient = MockApiClient();
      repository = ApiAgentSearchRepository(apiClient);
    });

    test('calls GET /api/agents/ with the search query', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 1,
                'next': null,
                'previous': null,
                'results': [_agentJson()],
              }));

      final results = await repository.searchAgents(search: 'Kouassi');

      expect(results, hasLength(1));
      final call = verify(
        () => apiClient.get<Map<String, dynamic>>(
          captureAny(),
          query: captureAny(named: 'query'),
        ),
      ).captured;
      expect(call.first, '/api/agents/');
      final query = call[1] as Map<String, dynamic>;
      expect(query['search'], 'Kouassi');
    });

    test('omits the search param entirely when no query is given', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 0,
                'next': null,
                'previous': null,
                'results': [],
              }));

      await repository.searchAgents();

      final query = verify(
        () => apiClient.get<Map<String, dynamic>>(any(), query: captureAny(named: 'query')),
      ).captured.single as Map<String, dynamic>;
      expect(query.containsKey('search'), isFalse);
    });
  });

  group('MockAgentSearchRepository', () {
    test('returns all demo agents when the search is empty', () async {
      final results = await MockAgentSearchRepository().searchAgents();
      expect(results, isNotEmpty);
    });

    test('filters demo agents by name or agency, case-insensitively', () async {
      final results = await MockAgentSearchRepository().searchAgents(search: 'kouakou');
      expect(results, isNotEmpty);
      expect(results.every((a) => a.fullName.toLowerCase().contains('kouakou')), isTrue);
    });
  });
}
