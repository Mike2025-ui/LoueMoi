import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/reservations/data/api_reservation_repository.dart';
import 'package:louemoi/features/reservations/models/reservation.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late MockApiClient apiClient;
  late ApiReservationRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ApiReservationRepository(apiClient);
  });

  test('createReservation sends the property id and amounts, and parses the server total',
      () async {
    when(() => apiClient.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _fakeResponse({
              'id': 10,
              'property_id': 3,
              'user_id': 1,
              'rent': 450000,
              'deposit': 1230000,
              'advance': 300000,
              'total': 1980000,
              'status': 'enCours',
              'created_at': '2026-01-01T00:00:00Z',
            }));

    final reservation = await repository.createReservation(
      propertyId: '3',
      rent: 450000,
      deposit: 1230000,
      advance: 300000,
    );

    // Le total vient du serveur (source de vérité), jamais recalculé côté client.
    expect(reservation.total, 1980000);
    expect(reservation.status, ReservationStatus.enCours);

    final captured = verify(
      () => apiClient.post<Map<String, dynamic>>(any(), data: captureAny(named: 'data')),
    ).captured.single as Map<String, dynamic>;
    expect(captured['property_id'], '3');
    expect(captured['rent'], 450000);
    expect(captured['deposit'], 1230000);
    expect(captured['advance'], 300000);
  });

  test('cancelReservation posts to the dedicated cancel action', () async {
    when(() => apiClient.post<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _fakeResponse({
              'id': 10,
              'property_id': 3,
              'user_id': 1,
              'rent': 450000,
              'deposit': 0,
              'advance': 0,
              'total': 450000,
              'status': 'annulee',
              'created_at': '2026-01-01T00:00:00Z',
            }));

    final reservation = await repository.cancelReservation('10');

    expect(reservation.status, ReservationStatus.annulee);
    verify(() => apiClient.post<Map<String, dynamic>>('/api/reservations/10/cancel/'))
        .called(1);
  });
}
