import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/agent_dashboard.dart';

/// Statistiques de l'espace bailleur — même forme que celles de l'espace
/// agent (voir AgentDashboard, réutilisé tel quel : propriétés/réservations/
/// favoris/vues/messages/avis n'ont rien de spécifique à un rôle), mais un
/// endpoint et un rôle strictement indépendants de ceux de l'agent.
abstract class BailleurRepository {
  Future<AgentDashboard> getDashboard();
}

class ApiBailleurRepository implements BailleurRepository {
  ApiBailleurRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AgentDashboard> getDashboard() async {
    final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.bailleurDashboard);
    return AgentDashboard.fromJson(response.data!);
  }
}

/// Version démo : un bailleur de démonstration qui vient tout juste de
/// s'inscrire (aucun bien mock ne lui appartient — voir
/// MockPropertyRepository.fetchMyPropertiesAsBailleur), donc des chiffres à
/// zéro plutôt que des valeurs inventées et incohérentes avec le reste du
/// mode mock.
class MockBailleurRepository implements BailleurRepository {
  @override
  Future<AgentDashboard> getDashboard() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const AgentDashboard(
      propertiesCount: 0,
      availableCount: 0,
      occupiedCount: 0,
      reservationsCount: 0,
      favoritesReceived: 0,
      viewsCount: 0,
      messagesCount: 0,
      reviewsCount: 0,
      averageRating: 0,
    );
  }
}
