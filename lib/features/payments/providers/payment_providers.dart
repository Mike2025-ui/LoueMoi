import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../data/api_payment_repository.dart';
import '../data/payment_repository.dart';
import '../models/payment_models.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return ApiPaymentRepository(ref.watch(apiClientProvider));
});

final userSubscriptionStatusProvider =
    FutureProvider.autoDispose<UserSubscriptionStatus>((ref) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.getSubscriptionStatus();
});

final canContactProvider =
    FutureProvider.autoDispose.family<CanContactResult, ({String? propertyId, String? ownerId})>(
  (ref, args) async {
    final repository = ref.watch(paymentRepositoryProvider);
    return repository.checkCanContact(
      propertyId: args.propertyId,
      ownerId: args.ownerId,
    );
  },
);

