import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/reservations/models/reservation.dart';

void main() {
  group('Reservation.total', () {
    test('is calculated dynamically from rent + deposit + advance', () {
      final reservation = Reservation(
        id: 'r1',
        propertyId: 'p1',
        userId: 'u1',
        rent: 450000,
        deposit: 1230000,
        advance: 300000,
        status: ReservationStatus.enCours,
        createdAt: DateTime(2026, 9, 12),
      );

      expect(reservation.total, 1980000);
    });

    test('updates automatically when the underlying amounts change', () {
      final reservation = Reservation(
        id: 'r2',
        propertyId: 'p2',
        userId: 'u1',
        rent: 100000,
        deposit: 0,
        advance: 0,
        status: ReservationStatus.enCours,
        createdAt: DateTime(2026, 9, 12),
      );

      expect(reservation.total, 100000);
    });
  });
}
