import '../models/reservation.dart';

abstract class ReservationRepository {
  Future<List<Reservation>> fetchReservations();
  Future<Reservation> createReservation({
    required String propertyId,
    required double rent,
    required double deposit,
    required double advance,
  });
  Future<Reservation> cancelReservation(String id);
}

class MockReservationRepository implements ReservationRepository {
  final List<Reservation> _reservations = [
    Reservation(
      id: 'res-1',
      propertyId: '5',
      userId: 'user-1',
      rent: 65000,
      deposit: 0,
      advance: 0,
      status: ReservationStatus.enCours,
      createdAt: DateTime(2026, 9, 12),
    ),
    Reservation(
      id: 'res-2',
      propertyId: '6',
      userId: 'user-1',
      rent: 43000000,
      deposit: 0,
      advance: 0,
      status: ReservationStatus.enCours,
      createdAt: DateTime(2026, 9, 12),
    ),
    Reservation(
      id: 'res-3',
      propertyId: '5',
      userId: 'user-1',
      rent: 65000,
      deposit: 0,
      advance: 0,
      status: ReservationStatus.accomplie,
      createdAt: DateTime(2026, 9, 12),
    ),
    Reservation(
      id: 'res-4',
      propertyId: '7',
      userId: 'user-1',
      rent: 65000,
      deposit: 0,
      advance: 0,
      status: ReservationStatus.annulee,
      createdAt: DateTime(2026, 9, 12),
    ),
  ];

  @override
  Future<List<Reservation>> fetchReservations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_reservations);
  }

  @override
  Future<Reservation> createReservation({
    required String propertyId,
    required double rent,
    required double deposit,
    required double advance,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final reservation = Reservation(
      id: 'res-${DateTime.now().millisecondsSinceEpoch}',
      propertyId: propertyId,
      userId: 'user-1',
      rent: rent,
      deposit: deposit,
      advance: advance,
      status: ReservationStatus.enCours,
      createdAt: DateTime.now(),
    );
    _reservations.insert(0, reservation);
    return reservation;
  }

  @override
  Future<Reservation> cancelReservation(String id) async {
    final index = _reservations.indexWhere((r) => r.id == id);
    final updated = Reservation(
      id: _reservations[index].id,
      propertyId: _reservations[index].propertyId,
      userId: _reservations[index].userId,
      rent: _reservations[index].rent,
      deposit: _reservations[index].deposit,
      advance: _reservations[index].advance,
      status: ReservationStatus.annulee,
      createdAt: _reservations[index].createdAt,
    );
    _reservations[index] = updated;
    return updated;
  }
}
