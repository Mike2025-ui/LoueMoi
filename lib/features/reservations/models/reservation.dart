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

class Reservation extends Equatable {
  final String id;
  final String propertyId;
  final String userId;
  final double rent;
  final double deposit;
  final double advance;
  final ReservationStatus status;
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.propertyId,
    required this.userId,
    required this.rent,
    required this.deposit,
    required this.advance,
    required this.status,
    required this.createdAt,
  });

  /// Total = loyer + caution + avance. Toujours calculé, jamais codé en dur.
  double get total => rent + deposit + advance;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'].toString(),
      propertyId: json['property_id'].toString(),
      userId: json['user_id'].toString(),
      rent: (json['rent'] as num).toDouble(),
      deposit: (json['deposit'] as num).toDouble(),
      advance: (json['advance'] as num).toDouble(),
      status: ReservationStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
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
      [id, propertyId, userId, rent, deposit, advance, status, createdAt];
}
