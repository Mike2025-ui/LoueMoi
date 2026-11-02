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
  final bool isApproved;
  final bool activationRequested;
  final bool isVerified;
  final bool hasActiveSubscription;
  final bool isStaff;
  final bool isSuperAdmin;

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
    this.isApproved = true,
    this.activationRequested = false,
    this.isVerified = false,
    this.hasActiveSubscription = false,
    this.isStaff = false,
    this.isSuperAdmin = false,
    this.agentProfile,
  });

  String get fullName => '$firstName $lastName';

  bool get isAgent => role == UserRole.agent;
  bool get isBailleur => role == UserRole.bailleur;
  bool get isClient => role == UserRole.client;
  bool get isAdmin => isStaff || isSuperAdmin;
  bool get isSuperAdminUser => isSuperAdmin || isStaff;

  /// Badge de certification : accordé automatiquement à tout utilisateur abonné
  /// ou certifié en base.
  bool get isVerifiedUser {
    if (isSuperAdminUser) return true;
    if (hasActiveSubscription) return true;
    if (isAgent) {
      return (agentProfile?.isVerified ?? false) || isVerified;
    }
    return isVerified;
  }

  /// Les comptes agent et bailleur doivent être approuvés par l'administrateur
  /// avant de pouvoir accéder à l'application.
  bool get needsActivation => !isSuperAdminUser && (isAgent || isBailleur) && !isApproved;

  /// Les administrateurs LoueMoi peuvent publier et gérer directement les annonces.
  bool get canPublish => isSuperAdminUser || isAgent || isBailleur;
  bool get canOwnProperties => canPublish;

  factory User.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['agent_profile'];
    final AgentProfile? agentProfile;
    if (rawProfile is Map<String, dynamic>) {
      agentProfile = AgentProfile.fromJson(rawProfile);
    } else if (rawProfile is Map) {
      agentProfile = AgentProfile.fromJson(Map<String, dynamic>.from(rawProfile));
    } else {
      agentProfile = null;
    }

    final role = UserRole.fromString(json['role']?.toString());
    final rawApproved = json['is_approved'];
    final bool isApproved;
    if (rawApproved != null) {
      isApproved = rawApproved == true ||
          rawApproved == 1 ||
          rawApproved.toString().toLowerCase() == 'true';
    } else {
      isApproved = role == UserRole.client;
    }

    final phone = json['phone']?.toString() ?? '';
    final whatsapp = json['whatsapp']?.toString();

    final rawActivation = json['activation_requested'];
    final activationRequested = rawActivation == true ||
        rawActivation == 1 ||
        rawActivation.toString().toLowerCase() == 'true';

    final rawVerified = json['is_verified'];
    final isVerified = rawVerified == true ||
        rawVerified == 1 ||
        rawVerified.toString().toLowerCase() == 'true';

    final rawSub = json['has_active_subscription'];
    final hasActiveSubscription = rawSub == true ||
        rawSub == 1 ||
        rawSub.toString().toLowerCase() == 'true';

    final rawStaff = json['is_staff'];
    final isStaff = rawStaff == true ||
        rawStaff == 1 ||
        rawStaff.toString().toLowerCase() == 'true';

    final rawSuperUser = json['is_superuser'];
    final isSuperAdmin = rawSuperUser == true ||
        rawSuperUser == 1 ||
        rawSuperUser.toString().toLowerCase() == 'true';

    return User(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      phone: phone,
      whatsapp: (whatsapp != null && whatsapp.isNotEmpty) ? whatsapp : phone,
      photo: json['photo']?.toString(),
      token: json['token']?.toString(),
      role: role,
      isApproved: isApproved,
      activationRequested: activationRequested,
      isVerified: isVerified,
      hasActiveSubscription: hasActiveSubscription,
      isStaff: isStaff,
      isSuperAdmin: isSuperAdmin,
      agentProfile: agentProfile,
    );
  }

  User copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? phone,
    String? whatsapp,
    String? photo,
    bool clearPhoto = false,
    String? token,
    UserRole? role,
    bool? isApproved,
    bool? activationRequested,
    bool? isVerified,
    bool? hasActiveSubscription,
    bool? isStaff,
    bool? isSuperAdmin,
    AgentProfile? agentProfile,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      photo: clearPhoto ? null : (photo ?? this.photo),
      token: token ?? this.token,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      activationRequested: activationRequested ?? this.activationRequested,
      isVerified: isVerified ?? this.isVerified,
      hasActiveSubscription: hasActiveSubscription ?? this.hasActiveSubscription,
      isStaff: isStaff ?? this.isStaff,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      agentProfile: agentProfile ?? this.agentProfile,
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
        'is_approved': isApproved,
        'activation_requested': activationRequested,
        'is_verified': isVerified,
        'has_active_subscription': hasActiveSubscription,
        'is_staff': isStaff,
        'is_superuser': isSuperAdmin,
      };

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        phone,
        whatsapp,
        photo,
        token,
        role,
        isApproved,
        activationRequested,
        isVerified,
        hasActiveSubscription,
        isStaff,
        isSuperAdmin,
        agentProfile,
      ];
}
