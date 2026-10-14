import 'package:equatable/equatable.dart';

/// Statut de la demande de certification — décision métier :
/// Agent → demande → enAttente → administrateur → approuvee/refusee.
/// Un agent ne peut jamais s'auto-certifier.
enum CertificationStatus {
  nonDemandee,
  enAttente,
  approuvee,
  refusee;

  String get label => switch (this) {
        CertificationStatus.nonDemandee => 'Non demandée',
        CertificationStatus.enAttente => 'En attente',
        CertificationStatus.approuvee => 'Approuvée',
        CertificationStatus.refusee => 'Refusée',
      };

  static CertificationStatus fromString(String? value) => switch (value) {
        'en_attente' => CertificationStatus.enAttente,
        'approuvee' => CertificationStatus.approuvee,
        'refusee' => CertificationStatus.refusee,
        _ => CertificationStatus.nonDemandee,
      };
}

/// Informations professionnelles de l'agent connecté (nested dans
/// GET /api/users/me/). `isVerified`/`rating`/`certificationStatus` sont en
/// lecture seule côté API — jamais modifiables depuis l'app, uniquement par
/// l'administration (sauf certificationStatus, que l'agent peut faire
/// passer à "en attente" via POST /api/agent/certification/request/, mais
/// jamais directement).
class AgentProfile extends Equatable {
  const AgentProfile({
    required this.agencyName,
    required this.whatsapp,
    required this.description,
    required this.isVerified,
    this.certificationStatus = CertificationStatus.nonDemandee,
    required this.rating,
  });

  final String agencyName;
  final String whatsapp;
  final String description;
  final bool isVerified;
  final CertificationStatus certificationStatus;
  final double rating;

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      agencyName: json['agency_name'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      certificationStatus: CertificationStatus.fromString(json['certification_status'] as String?),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [agencyName, whatsapp, description, isVerified, certificationStatus, rating];
}
