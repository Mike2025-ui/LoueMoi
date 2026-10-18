import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/payment_models.dart';
import 'payment_repository.dart';

class ApiPaymentRepository implements PaymentRepository {
  ApiPaymentRepository(this._client);

  final ApiClient _client;

  @override
  Future<CanContactResult> checkCanContact({String? propertyId, String? ownerId}) async {
    final endpoint = ApiEndpoints.canContact(propertyId: propertyId, ownerId: ownerId);
    final response = await _client.get<Map<String, dynamic>>(endpoint);
    return CanContactResult.fromJson(response.data ?? {});
  }

  @override
  Future<UserSubscriptionStatus> getSubscriptionStatus() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.subscriptionStatus,
    );
    return UserSubscriptionStatus.fromJson(response.data ?? {});
  }

  @override
  Future<SubscriptionResult> createSubscription({
    required PaymentMethod paymentMethod,
    String? payerPhone,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.subscriptionCreate,
      data: {
        'payment_method': paymentMethod.code,
        if (payerPhone != null && payerPhone.isNotEmpty) 'payer_phone': payerPhone,
      },
    );
    return SubscriptionResult.fromJson(response.data ?? {});
  }
}
