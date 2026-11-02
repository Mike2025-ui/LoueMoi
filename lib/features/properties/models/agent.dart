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

  const Agent.empty()
    : this(
        id: '',
        firstName: 'LoueMoi',
        lastName: '',
        phone: '',
        whatsapp: '',
        isVerified: true,
        hasActiveSubscription: true,
      );

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

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return num.tryParse(value.toString())?.toDouble();
  }

  factory Agent.fromJson(Map<String, dynamic> json) {
    final rawVerified = json['is_verified'];
    final isVerified =
        rawVerified == true ||
        rawVerified == 1 ||
        rawVerified?.toString().toLowerCase() == 'true';

    final rawSub = json['has_active_subscription'];
    final hasActiveSubscription =
        rawSub == true ||
        rawSub == 1 ||
        rawSub?.toString().toLowerCase() == 'true';

    return Agent(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? 'LoueMoi',
      lastName: json['last_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      whatsapp: json['whatsapp']?.toString() ?? '',
      photo: json['photo']?.toString(),
      isVerified: rawVerified != null ? isVerified : true,
      rating: _parseDouble(json['rating']) ?? 5.0,
      hasActiveSubscription: rawSub != null ? hasActiveSubscription : true,
      role: json['role']?.toString() ?? 'agent',
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
