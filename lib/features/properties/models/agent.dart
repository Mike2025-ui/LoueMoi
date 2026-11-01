import 'package:equatable/equatable.dart';

class Agent extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String whatsapp;
  final String? photo;
  final bool isVerified;
  final double rating;
  final bool hasActiveSubscription;
  final String role;

  const Agent({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.whatsapp,
    this.photo,
    this.isVerified = false,
    this.rating = 0,
    this.hasActiveSubscription = false,
    this.role = 'agent',
  });

  /// Nom court affiché en en-tête (ex: "LoueMoi").
  String get shortName {
    if (firstName.trim().isNotEmpty) return firstName.trim();
    return 'LoueMoi';
  }

  /// Nom complet affiché en sous-titre (ex: "LoueMoi Immobilier").
  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : 'LoueMoi Immobilier';
  }

  bool get isBailleur => role == 'bailleur';
  String get roleLabel => 'Service officiel LoueMoi';

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id']?.toString() ?? '',
      firstName: (json['first_name'] as String?) ?? 'LoueMoi',
      lastName: (json['last_name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      whatsapp: (json['whatsapp'] as String?) ?? '',
      photo: json['photo'] as String?,
      isVerified: json['is_verified'] as bool? ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? true,
      role: json['role'] as String? ?? 'agent',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'whatsapp': whatsapp,
        'photo': photo,
        'is_verified': isVerified,
        'rating': rating,
        'has_active_subscription': hasActiveSubscription,
        'role': role,
      };

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        phone,
        whatsapp,
        photo,
        role,
        isVerified,
        rating,
        hasActiveSubscription,
      ];
}
