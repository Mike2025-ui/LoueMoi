import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/payment_models.dart';
import 'payment_repository.dart';

class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._client);

  final ApiClient _client;

  @override
  Future<CanContactResult> checkCanContact({String? propertyId, String? ownerId}) async {
    return const CanContactResult(
      canContact: true,
      reason: '',
      ownerHasActiveSubscription: true,
      userHasActiveSubscription: true,
    );
  }

  @override
  Future<UserSubscriptionStatus> getSubscriptionStatus() async {
    return const UserSubscriptionStatus(
      hasActiveSubscription: true,
      role: 'client',
      requiredPlan: 'client',
      planPrice: 0,
    );
  }

  @override
  Future<SubscriptionResult> createSubscription({
    required PaymentMethod paymentMethod,
    String? payerPhone,
  }) async {
    return const SubscriptionResult(
      reference: 'FREE',
      redirectUrl: '',
      amount: 0,
      plan: 'free',
      paymentMethod: 'none',
      isSimulation: true,
    );
  }
}

