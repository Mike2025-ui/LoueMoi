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
  });

  /// Nom court affiché en en-tête (ex: "Mme Kouakou").
  String get shortName => firstName;

  /// Nom complet affiché en sous-titre (ex: "Marie Therese Ange").
  String get fullName => lastName;

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'].toString(),
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String,
      whatsapp: json['whatsapp'] as String,
      photo: json['photo'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? false,
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
      };

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        phone,
        whatsapp,
        photo,
        isVerified,
        rating,
        hasActiveSubscription,
      ];
}
