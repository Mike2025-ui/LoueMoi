import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/agent_search_result.dart';

abstract class AgentSearchRepository {
  /// [search] filtre sur nom/prénom/nom d'agence, [city] sur les communes
  /// où l'agent a des annonces — filtrage toujours côté serveur.
  Future<List<AgentSearchResult>> searchAgents({String? search, String? city});
}

class ApiAgentSearchRepository implements AgentSearchRepository {
  ApiAgentSearchRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<AgentSearchResult>> searchAgents({String? search, String? city}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.agentsSearch,
      query: {
        'page_size': 100,
        if (search != null && search.isNotEmpty) 'search': search,
        if (city != null && city.isNotEmpty) 'city': city,
      },
    );
    final results = response.data!['results'] as List;
    return results
        .map((json) => AgentSearchResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

class MockAgentSearchRepository implements AgentSearchRepository {
  static final _agents = [
    const AgentSearchResult(
      id: 'agent-1',
      firstName: 'Mme Kouakou',
      lastName: 'Marie Therese Ange',
      phone: '+225 07 00 00 00 00',
      agencyName: 'Kouakou Immobilier',
      description: 'Spécialiste location/vente à Cocody depuis 8 ans.',
      rating: 4.8,
      isVerified: true,
    ),
    const AgentSearchResult(
      id: 'agent-2',
      firstName: 'M. Kouassi',
      lastName: 'Jean Baptiste',
      phone: '+225 07 11 11 11 11',
      agencyName: 'ABC Immo',
      description: 'Terrains et magasins, Yopougon et environs.',
      rating: 4.2,
      isVerified: false,
    ),
  ];

  @override
  Future<List<AgentSearchResult>> searchAgents({String? search, String? city}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (search == null || search.isEmpty) return _agents;
    final query = search.toLowerCase();
    return _agents
        .where(
          (a) => a.fullName.toLowerCase().contains(query) ||
              a.agencyName.toLowerCase().contains(query),
        )
        .toList();
  }
}
