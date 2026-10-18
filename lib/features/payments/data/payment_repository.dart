import '../models/payment_models.dart';

abstract class PaymentRepository {
  /// Vérifie si l'utilisateur peut contacter le propriétaire (propriété ou profil)
  Future<CanContactResult> checkCanContact({String? propertyId, String? ownerId});

  /// Récupère le statut d'abonnement de l'utilisateur connecté
  Future<UserSubscriptionStatus> getSubscriptionStatus();

  /// Crée un abonnement mensuel et initie le paiement Jèko Checkout
  Future<SubscriptionResult> createSubscription({
    required PaymentMethod paymentMethod,
    String? payerPhone,
  });
}
