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
    final rawVerified = json['is_verified'];
    final isVerified =
        rawVerified == true ||
        rawVerified == 1 ||
        rawVerified?.toString().toLowerCase() == 'true';

    final rawRating = json['rating'];
    final double rating = rawRating is num
        ? rawRating.toDouble()
        : (double.tryParse(rawRating?.toString() ?? '') ?? 0.0);

    return AgentSearchResult(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      photo: json['photo']?.toString(),
      phone: json['phone']?.toString() ?? '',
      agencyName: json['agency_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      rating: rating,
      isVerified: isVerified,
    );
  }

  @override
  List<Object?> get props =>
      [id, firstName, lastName, photo, phone, agencyName, description, rating, isVerified];
}
