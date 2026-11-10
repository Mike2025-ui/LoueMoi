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

  String get initials {
    final f = firstName.trim().isNotEmpty ? firstName.trim()[0].toUpperCase() : '';
    final l = lastName.trim().isNotEmpty ? lastName.trim()[0].toUpperCase() : '';
    final res = '$f$l'.trim();
    return res.isNotEmpty ? res : (fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?');
  }

  factory BailleurSearchResult.fromJson(Map<String, dynamic> json) {
    return BailleurSearchResult(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      photo: json['photo']?.toString(),
      phone: json['phone']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [id, firstName, lastName, photo, phone];
}
