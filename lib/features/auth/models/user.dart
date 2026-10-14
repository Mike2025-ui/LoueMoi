import 'package:equatable/equatable.dart';
import '../../profile/models/agent_profile.dart';
import 'user_role.dart';

class User extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String whatsapp;
  final String? photo;
  final String? token;
  final UserRole role;

  /// Non-null uniquement quand [role] == [UserRole.agent] — un client n'a
  /// jamais de profil agent.
  final AgentProfile? agentProfile;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.whatsapp,
    this.photo,
    this.token,
    this.role = UserRole.client,
    this.agentProfile,
  });

  String get fullName => '$firstName $lastName';

  bool get isAgent => role == UserRole.agent;
  bool get isBailleur => role == UserRole.bailleur;

  /// Agent et bailleur sont deux rôles indépendants pouvant tous deux
  /// publier/posséder des annonces — aucune délégation entre eux.
  bool get canOwnProperties => isAgent || isBailleur;

  factory User.fromJson(Map<String, dynamic> json) {
    final agentProfileJson = json['agent_profile'] as Map<String, dynamic>?;
    return User(
      id: json['id'].toString(),
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String,
      whatsapp: json['whatsapp'] as String? ?? json['phone'] as String,
      photo: json['photo'] as String?,
      token: json['token'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      agentProfile: agentProfileJson != null ? AgentProfile.fromJson(agentProfileJson) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'whatsapp': whatsapp,
        'photo': photo,
        'token': token,
        'role': role.toJson(),
      };

  @override
  List<Object?> get props =>
      [id, firstName, lastName, phone, whatsapp, photo, token, role, agentProfile];
}
