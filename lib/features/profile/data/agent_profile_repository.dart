import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../models/agent_profile.dart';

/// PATCH /api/agent/profile/ — agence, whatsapp professionnel, description
/// (voir AgentProfileSerializer côté Django : `is_verified`/`rating` restent
/// toujours en lecture seule, jamais modifiables depuis cet écran, même en
/// mode mock).
abstract class AgentProfileRepository {
  Future<AgentProfile> updateAgentProfile(Map<String, dynamic> changes);

  /// POST /api/agent/certification/request/ — fait passer le statut à "en
  /// attente". Ne certifie jamais directement (voir CertificationStatus) :
  /// lève une [ApiException] (400) si une demande est déjà en attente ou
  /// déjà approuvée.
  Future<AgentProfile> requestCertification();
}

class ApiAgentProfileRepository implements AgentProfileRepository {
  ApiAgentProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AgentProfile> updateAgentProfile(Map<String, dynamic> changes) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiEndpoints.agentProfileMe,
      data: changes,
    );
    return AgentProfile.fromJson(response.data!);
  }

  @override
  Future<AgentProfile> requestCertification() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.agentCertificationRequest,
    );
    return AgentProfile.fromJson(response.data!);
  }
}

/// Aucun état serveur persisté en mode mock : renvoie simplement les
/// changements fusionnés sur un profil vide, is_verified/rating toujours à
/// leur valeur par défaut (jamais modifiables, même ici). Seul
/// _certificationStatus est gardé en mémoire, pour que "déjà en attente"
/// se comporte de façon plausible d'un appel à l'autre dans la démo.
class MockAgentProfileRepository implements AgentProfileRepository {
  CertificationStatus _certificationStatus = CertificationStatus.nonDemandee;

  @override
  Future<AgentProfile> updateAgentProfile(Map<String, dynamic> changes) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return AgentProfile(
      agencyName: changes['agency_name'] as String? ?? '',
      whatsapp: changes['whatsapp'] as String? ?? '',
      description: changes['description'] as String? ?? '',
      isVerified: false,
      certificationStatus: _certificationStatus,
      rating: 0,
    );
  }

  @override
  Future<AgentProfile> requestCertification() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_certificationStatus == CertificationStatus.enAttente ||
        _certificationStatus == CertificationStatus.approuvee) {
      throw const ValidationException('Une demande de certification est déjà en attente.');
    }
    _certificationStatus = CertificationStatus.enAttente;
    return AgentProfile(
      agencyName: '',
      whatsapp: '',
      description: '',
      isVerified: false,
      certificationStatus: _certificationStatus,
      rating: 0,
    );
  }
}
