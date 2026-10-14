import 'package:equatable/equatable.dart';

/// Résultat public de GET /api/bailleurs/ — symétrique de AgentSearchResult
/// (agent → bailleur). Jamais de données privées (mot de passe, tokens...),
/// uniquement ce qui est nécessaire pour identifier puis contacter un
/// bailleur. Un bailleur n'a pas de profil professionnel séparé (pas
/// d'agence/description/note comme un agent) — ces champs n'existent pas
/// ici, volontairement.
class BailleurSearchResult extends Equatable {
  const BailleurSearchResult({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photo,
    required this.phone,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? photo;
  final String phone;

  String get fullName => '$firstName $lastName'.trim();

  factory BailleurSearchResult.fromJson(Map<String, dynamic> json) {
    return BailleurSearchResult(
      id: json['id'].toString(),
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      photo: json['photo'] as String?,
      phone: json['phone'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, firstName, lastName, photo, phone];
}
