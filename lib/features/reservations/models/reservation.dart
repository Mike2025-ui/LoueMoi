import 'package:equatable/equatable.dart';

enum ReservationStatus {
  enCours,
  accomplie,
  annulee;

  String get label => switch (this) {
        ReservationStatus.enCours => 'En cours',
        ReservationStatus.accomplie => 'Accomplies',
        ReservationStatus.annulee => 'Annulées',
      };

  static ReservationStatus fromString(String value) => ReservationStatus.values
      .firstWhere((e) => e.name == value, orElse: () => ReservationStatus.enCours);
}

/// Coordonnées publiques du client qui a réservé — visibles uniquement par
/// le propriétaire du bien (agent/bailleur), jamais par un tiers : le
/// backend ne renvoie ce champ que dans les réservations que l'utilisateur
/// connecté a le droit de voir (voir ReservationViewSet.get_queryset côté
/// Django).
class ReservationClient extends Equatable {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String whatsapp;

  const ReservationClient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.whatsapp,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ReservationClient.fromJson(Map<String, dynamic> json) {
    return ReservationClient(
      id: json['id'].toString(),
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, firstName, lastName, phone, whatsapp];
}

class Reservation extends Equatable {
  final String id;
  final String propertyId;
  final String userId;
  final ReservationClient? client;
  final double rent;
  final double deposit;
  final double advance;
  final ReservationStatus status;
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.propertyId,
    required this.userId,
    this.client,
    required this.rent,
    required this.deposit,
    required this.advance,
    required this.status,
    required this.createdAt,
  });

  /// Total = loyer + caution + avance. Toujours calculé, jamais codé en dur.
  double get total => rent + deposit + advance;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final clientJson = json['client'] as Map<String, dynamic>?;
    return Reservation(
      id: json['id'].toString(),
      propertyId: json['property_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      client: clientJson == null ? null : ReservationClient.fromJson(clientJson),
      rent: (json['rent'] as num?)?.toDouble() ??
          (num.tryParse(json['rent']?.toString() ?? '')?.toDouble() ?? 0.0),
      deposit: (json['deposit'] as num?)?.toDouble() ??
          (num.tryParse(json['deposit']?.toString() ?? '')?.toDouble() ?? 0.0),
      advance: (json['advance'] as num?)?.toDouble() ??
          (num.tryParse(json['advance']?.toString() ?? '')?.toDouble() ?? 0.0),
      status: ReservationStatus.fromString(json['status']?.toString() ?? 'enCours'),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'property_id': propertyId,
        'user_id': userId,
        'rent': rent,
        'deposit': deposit,
        'advance': advance,
        'total': total,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, propertyId, userId, client, rent, deposit, advance, status, createdAt];
}
