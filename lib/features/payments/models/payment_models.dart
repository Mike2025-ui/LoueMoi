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
    return CanContactResult(
      canContact: json['can_contact'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      ownerHasActiveSubscription: json['owner_has_active_subscription'] as bool? ?? false,
      userHasActiveSubscription: json['user_has_active_subscription'] as bool? ?? false,
      clientPlanPrice: json['client_plan_price'] as int? ?? 1000,
      proPlanPrice: json['pro_plan_price'] as int? ?? 3000,
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
    return SubscriptionResult(
      reference: json['reference'] as String? ?? '',
      redirectUrl: json['redirect_url'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      plan: json['plan'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      isSimulation: json['is_simulation'] as bool? ?? false,
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
    final sub = json['subscription'] as Map<String, dynamic>?;
    return UserSubscriptionStatus(
      hasActiveSubscription: json['has_active_subscription'] as bool? ?? false,
      role: json['role'] as String? ?? 'client',
      requiredPlan: json['required_plan'] as String? ?? 'client',
      planPrice: json['plan_price'] as int? ?? 1000,
      expiresAt: sub?['expires_at'] as String?,
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

