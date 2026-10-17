import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/reservation.dart';
import 'reservation_repository.dart';

/// Implémentation réelle, branchée sur `/api/reservations/`. Django est la
/// source de vérité pour le calcul et la validation du montant (le total
/// affiché côté Flutter avant envoi n'est qu'un aperçu UI) : si la propriété
/// n'est plus disponible, la création échoue avec un [ValidationException]
/// explicite (cf. ApiClient/ApiExceptions).
class ApiReservationRepository implements ReservationRepository {
  ApiReservationRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Reservation>> fetchReservations() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.reservations,
      query: {'page_size': 100},
    );
    final results = response.data!['results'] as List;
    return results
        .map((json) => Reservation.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Reservation> createReservation({
    required String propertyId,
    required double rent,
    required double deposit,
    required double advance,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reservations,
      data: {
        'property_id': propertyId,
        'rent': rent,
        'deposit': deposit,
        'advance': advance,
      },
    );
    return Reservation.fromJson(response.data!);
  }

  @override
  Future<Reservation> cancelReservation(String id) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reservationCancel(id),
    );
    return Reservation.fromJson(response.data!);
  }

  @override
  Future<Reservation> completeReservation(String id) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reservationComplete(id),
    );
    return Reservation.fromJson(response.data!);
  }

  @override
  Future<String> getOrCreateConversationId(String reservationId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.reservationConversation(reservationId),
    );
    return response.data!['id'].toString();
  }

  @override
  Future<void> deleteReservation(String id) async {
    await _apiClient.delete<dynamic>(ApiEndpoints.reservationDetail(id));
  }
}
