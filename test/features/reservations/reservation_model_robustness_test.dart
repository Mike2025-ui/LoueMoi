import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/reservations/models/reservation.dart';

void main() {
  group('Reservation.fromJson Robustness Tests', () {
    test('handles snake_case and non-standard status strings', () {
      expect(ReservationStatus.fromString('en_cours'), equals(ReservationStatus.enCours));
      expect(ReservationStatus.fromString('enCours'), equals(ReservationStatus.enCours));
      expect(ReservationStatus.fromString('accomplie'), equals(ReservationStatus.accomplie));
      expect(ReservationStatus.fromString('completed'), equals(ReservationStatus.accomplie));
      expect(ReservationStatus.fromString('annulee'), equals(ReservationStatus.annulee));
      expect(ReservationStatus.fromString('cancelled'), equals(ReservationStatus.annulee));
      expect(ReservationStatus.fromString('canceled'), equals(ReservationStatus.annulee));
    });

    test('handles string amounts and null id gracefully', () {
      final json = <String, dynamic>{
        'id': 101,
        'property_id': 202,
        'user_id': 303,
        'rent': '150000.00',
        'deposit': '300000',
        'advance': '150000',
        'status': 'en_cours',
      };

      final reservation = Reservation.fromJson(json);
      expect(reservation.id, equals('101'));
      expect(reservation.propertyId, equals('202'));
      expect(reservation.userId, equals('303'));
      expect(reservation.rent, equals(150000.0));
      expect(reservation.deposit, equals(300000.0));
      expect(reservation.advance, equals(150000.0));
      expect(reservation.total, equals(600000.0));
      expect(reservation.status, equals(ReservationStatus.enCours));
    });

    test('handles untyped client map safely', () {
      final dynamic untypedClient = <dynamic, dynamic>{
        'id': 77,
        'first_name': 'Fatou',
        'last_name': 'Bamba',
        'phone': '0505050505',
        'whatsapp': '0505050505',
      };

      final json = <String, dynamic>{
        'id': 'res-1',
        'client': untypedClient,
      };

      final reservation = Reservation.fromJson(json);
      expect(reservation.client, isNotNull);
      expect(reservation.client!.fullName, equals('Fatou Bamba'));
      expect(reservation.client!.phone, equals('0505050505'));
    });
  });
}

