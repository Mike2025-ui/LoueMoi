import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/bailleur_search_result.dart';

abstract class BailleurSearchRepository {
  /// [search] filtre sur nom/prénom, [city] sur les communes où le
  /// bailleur a des annonces — filtrage toujours côté serveur.
  Future<List<BailleurSearchResult>> searchBailleurs({String? search, String? city});
}

class ApiBailleurSearchRepository implements BailleurSearchRepository {
  ApiBailleurSearchRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<BailleurSearchResult>> searchBailleurs({String? search, String? city}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.bailleursSearch,
      query: {
        'page_size': 100,
        if (search != null && search.isNotEmpty) 'search': search,
        if (city != null && city.isNotEmpty) 'city': city,
      },
    );
    final results = response.data!['results'] as List;
    return results
        .map((json) => BailleurSearchResult.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

class MockBailleurSearchRepository implements BailleurSearchRepository {
  static const _bailleurs = [
    BailleurSearchResult(
      id: 'bailleur-1',
      firstName: 'Mme Coulibaly',
      lastName: 'Aminata',
      phone: '+225 07 22 22 22 22',
    ),
    BailleurSearchResult(
      id: 'bailleur-2',
      firstName: 'M. Traore',
      lastName: 'Ibrahim',
      phone: '+225 07 33 33 33 33',
    ),
  ];

  @override
  Future<List<BailleurSearchResult>> searchBailleurs({String? search, String? city}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (search == null || search.isEmpty) return _bailleurs;
    final query = search.toLowerCase();
    return _bailleurs.where((b) => b.fullName.toLowerCase().contains(query)).toList();
  }
}
