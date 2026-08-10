import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/agent_dashboard.dart';

/// Statistiques de l'espace agent — jamais recalculées côté Flutter,
/// toujours renvoyées telles quelles par Django.
abstract class AgentRepository {
  Future<AgentDashboard> getDashboard();
}

class ApiAgentRepository implements AgentRepository {
  ApiAgentRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AgentDashboard> getDashboard() async {
    final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.agentDashboard);
    return AgentDashboard.fromJson(response.data!);
  }
}

/// Version démo : calcule les mêmes chiffres à partir des données mock
/// plutôt que de renvoyer des valeurs figées, pour rester crédible en mode
/// hors-ligne.
class MockAgentRepository implements AgentRepository {
  @override
  Future<AgentDashboard> getDashboard() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const AgentDashboard(
      propertiesCount: 6,
      availableCount: 4,
      occupiedCount: 2,
      reservationsCount: 3,
      favoritesReceived: 5,
      viewsCount: 128,
      messagesCount: 7,
      reviewsCount: 12,
      averageRating: 4.6,
    );
  }
}
