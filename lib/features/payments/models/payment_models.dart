import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum PaymentMethod {
  wave(
    code: 'wave',
    label: 'Wave',
    assetPath: 'assets/icons/wave.png',
    brandColor: Color(0xFF1BA4D9),
    brandTextColor: Colors.white,
  ),
  orange(
    code: 'orange',
    label: 'Orange Money',
    assetPath: 'assets/icons/orange_money.png',
    brandColor: Color(0xFFFF7900),
    brandTextColor: Colors.white,
  ),
  mtn(
    code: 'mtn',
    label: 'MTN MoMo',
    assetPath: 'assets/icons/mtn_momo.png',
    brandColor: Color(0xFFFFCC00),
    brandTextColor: Color(0xFF000000),
  ),
  moov(
    code: 'moov',
    label: 'Moov Money',
    assetPath: 'assets/icons/moov_money.png',
    brandColor: Color(0xFF005CA9),
    brandTextColor: Colors.white,
  );

  final String code;
  final String label;
  final String assetPath;
  final Color brandColor;
  final Color brandTextColor;

  const PaymentMethod({
    required this.code,
    required this.label,
    required this.assetPath,
    required this.brandColor,
    required this.brandTextColor,
  });

  static PaymentMethod fromCode(String code) {
    return PaymentMethod.values.firstWhere(
      (m) => m.code.toLowerCase() == code.toLowerCase(),
      orElse: () => PaymentMethod.wave,
    );
  }
}

class CanContactResult extends Equatable {
  final bool canContact;
  final String reason;
  final bool ownerHasActiveSubscription;
  final bool userHasActiveSubscription;
  final int clientPlanPrice;
  final int proPlanPrice;

  const CanContactResult({
    required this.canContact,
    required this.reason,
    required this.ownerHasActiveSubscription,
    required this.userHasActiveSubscription,
    this.clientPlanPrice = 1000,
    this.proPlanPrice = 3000,
  });

  factory CanContactResult.fromJson(Map<String, dynamic> json) {
    final rawCan = json['can_contact'];
    final canContact = rawCan == true ||
        rawCan == 1 ||
        rawCan?.toString().toLowerCase() == 'true';

    final rawOwner = json['owner_has_active_subscription'];
    final ownerHasActiveSubscription = rawOwner == true ||
        rawOwner == 1 ||
        rawOwner?.toString().toLowerCase() == 'true';

    final rawUser = json['user_has_active_subscription'];
    final userHasActiveSubscription = rawUser == true ||
        rawUser == 1 ||
        rawUser?.toString().toLowerCase() == 'true';

    final rawClientPrice = json['client_plan_price'];
    final clientPlanPrice = rawClientPrice is num
        ? rawClientPrice.toInt()
        : (int.tryParse(rawClientPrice?.toString() ?? '') ?? 1000);

    final rawProPrice = json['pro_plan_price'];
    final proPlanPrice = rawProPrice is num
        ? rawProPrice.toInt()
        : (int.tryParse(rawProPrice?.toString() ?? '') ?? 3000);

    return CanContactResult(
      canContact: canContact,
      reason: json['reason']?.toString() ?? '',
      ownerHasActiveSubscription: ownerHasActiveSubscription,
      userHasActiveSubscription: userHasActiveSubscription,
      clientPlanPrice: clientPlanPrice,
      proPlanPrice: proPlanPrice,
    );
  }

  @override
  List<Object?> get props => [
        canContact,
        reason,
        ownerHasActiveSubscription,
        userHasActiveSubscription,
        clientPlanPrice,
        proPlanPrice,
      ];
}

class SubscriptionResult extends Equatable {
  final String reference;
  final String redirectUrl;
  final int amount;
  final String plan;
  final String paymentMethod;
  final bool isSimulation;

  const SubscriptionResult({
    required this.reference,
    required this.redirectUrl,
    required this.amount,
    required this.plan,
    required this.paymentMethod,
    this.isSimulation = false,
  });

  factory SubscriptionResult.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.toInt()
        : (int.tryParse(rawAmount?.toString() ?? '') ?? 0);

    final rawSim = json['is_simulation'];
    final isSimulation = rawSim == true ||
        rawSim == 1 ||
        rawSim?.toString().toLowerCase() == 'true';

    return SubscriptionResult(
      reference: json['reference']?.toString() ?? '',
      redirectUrl: json['redirect_url']?.toString() ?? '',
      amount: amount,
      plan: json['plan']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      isSimulation: isSimulation,
    );
  }

  @override
  List<Object?> get props => [
        reference,
        redirectUrl,
        amount,
        plan,
        paymentMethod,
        isSimulation,
      ];
}

class UserSubscriptionStatus extends Equatable {
  final bool hasActiveSubscription;
  final String role;
  final String requiredPlan;
  final int planPrice;
  final String? expiresAt;

  const UserSubscriptionStatus({
    required this.hasActiveSubscription,
    required this.role,
    required this.requiredPlan,
    required this.planPrice,
    this.expiresAt,
  });

  factory UserSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final rawSub = json['subscription'];
    final Map<String, dynamic>? sub = rawSub is Map<String, dynamic>
        ? rawSub
        : (rawSub is Map ? Map<String, dynamic>.from(rawSub) : null);

    final rawActive = json['has_active_subscription'];
    final hasActiveSubscription = rawActive == true ||
        rawActive == 1 ||
        rawActive?.toString().toLowerCase() == 'true';

    final rawPrice = json['plan_price'];
    final planPrice = rawPrice is num
        ? rawPrice.toInt()
        : (int.tryParse(rawPrice?.toString() ?? '') ?? 1000);

    return UserSubscriptionStatus(
      hasActiveSubscription: hasActiveSubscription,
      role: json['role']?.toString() ?? 'client',
      requiredPlan: json['required_plan']?.toString() ?? 'client',
      planPrice: planPrice,
      expiresAt: sub?['expires_at']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        hasActiveSubscription,
        role,
        requiredPlan,
        planPrice,
        expiresAt,
      ];
}

