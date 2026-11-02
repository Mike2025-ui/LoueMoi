import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/api_reservation_repository.dart';
import '../data/reservation_repository.dart';
import '../models/reservation.dart';
import '../../properties/providers/property_providers.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  if (Env.useMockData) return MockReservationRepository();
  return ApiReservationRepository(ref.watch(apiClientProvider));
});

final reservationsListProvider = FutureProvider<List<Reservation>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null && !Env.useMockData) return const [];
  final repository = ref.watch(reservationRepositoryProvider);
  return repository.fetchReservations();
});

final reservationsByStatusProvider =
    Provider.family<AsyncValue<List<Reservation>>, ReservationStatus>((ref, status) {
  final reservations = ref.watch(reservationsListProvider);
  return reservations.whenData(
    (list) => list.where((r) => r.status == status).toList(),
  );
});

Future<Reservation> createReservation(
  WidgetRef ref, {
  required String propertyId,
  required double rent,
  required double deposit,
  required double advance,
}) async {
  final repository = ref.read(reservationRepositoryProvider);
  final reservation = await repository.createReservation(
    propertyId: propertyId,
    rent: rent,
    deposit: deposit,
    advance: advance,
  );
  ref.invalidate(reservationsListProvider);
  return reservation;
}

Future<void> cancelReservation(WidgetRef ref, String id) async {
  final repository = ref.read(reservationRepositoryProvider);
  await repository.cancelReservation(id);
  ref.invalidate(reservationsListProvider);
  ref.invalidate(myPropertiesProvider);
  ref.invalidate(propertiesControllerProvider);
  ref.invalidate(propertiesListProvider);
}

/// Réservé au propriétaire du bien — voir le bouton "Valider" de
/// ReservationCard.
Future<void> completeReservation(WidgetRef ref, String id) async {
  final repository = ref.read(reservationRepositoryProvider);
  await repository.completeReservation(id);
  ref.invalidate(reservationsListProvider);
  ref.invalidate(myPropertiesProvider);
  ref.invalidate(propertiesControllerProvider);
  ref.invalidate(propertiesListProvider);
}

Future<void> deleteReservation(WidgetRef ref, String id) async {
  final repository = ref.read(reservationRepositoryProvider);
  await repository.deleteReservation(id);
  ref.invalidate(reservationsListProvider);
}
