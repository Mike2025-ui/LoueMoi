import 'package:equatable/equatable.dart';

/// Résultat public de GET /api/agents/ — jamais de données privées
/// (mot de passe, tokens...), uniquement ce qui est nécessaire pour choisir
/// puis contacter un agent (bailleur → agent).
class AgentSearchResult extends Equatable {
  const AgentSearchResult({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    required this.phone,
    required this.agencyName,
    required this.description,
    required this.rating,
    required this.isVerified,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? photo;
  final String phone;
  final String agencyName;
  final String description;
  final double rating;
  final bool isVerified;

  String get fullName => '$firstName $lastName'.trim();

  factory AgentSearchResult.fromJson(Map<String, dynamic> json) {
    return AgentSearchResult(
      id: json['id'].toString(),
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      photo: json['photo'] as String?,
      phone: json['phone'] as String? ?? '',
      agencyName: json['agency_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [id, firstName, lastName, photo, phone, agencyName, description, rating, isVerified];
}
