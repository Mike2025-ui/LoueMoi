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

  static ReservationStatus fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    return switch (normalized) {
      'accomplie' || 'completed' => ReservationStatus.accomplie,
      'annulee' || 'cancelled' || 'canceled' => ReservationStatus.annulee,
      _ => ReservationStatus.enCours,
    };
  }
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
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      whatsapp: json['whatsapp']?.toString() ?? '',
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

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return num.tryParse(value.toString())?.toDouble() ?? 0.0;
  }

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final rawClient = json['client'];
    final ReservationClient? client;
    if (rawClient is Map<String, dynamic>) {
      client = ReservationClient.fromJson(rawClient);
    } else if (rawClient is Map) {
      client = ReservationClient.fromJson(Map<String, dynamic>.from(rawClient));
    } else {
      client = null;
    }

    return Reservation(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      client: client,
      rent: _parseDouble(json['rent']),
      deposit: _parseDouble(json['deposit']),
      advance: _parseDouble(json['advance']),
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
