import 'package:equatable/equatable.dart';

/// Informations professionnelles de l'agent connecté (nested dans
/// GET /api/users/me/). `isVerified`/`rating` sont en lecture seule côté
/// API — jamais modifiables depuis l'app, uniquement par l'administration.
class AgentProfile extends Equatable {
  const AgentProfile({
    required this.agencyName,
    required this.whatsapp,
    required this.description,
    required this.isVerified,
    required this.rating,
  });

  final String agencyName;
  final String whatsapp;
  final String description;
  final bool isVerified;
  final double rating;

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      agencyName: json['agency_name'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  List<Object?> get props => [agencyName, whatsapp, description, isVerified, rating];
}
