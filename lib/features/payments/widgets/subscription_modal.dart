import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';

Future<bool?> showSubscriptionModal(
  BuildContext context, {
  required bool isPro,
  String? propertyId,
  String? reason,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) => _SubscriptionSheet(
      isPro: isPro,
      propertyId: propertyId,
      reason: reason,
    ),
  );
}

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({
    required this.isPro,
    this.propertyId,
    this.reason,
  });

  final bool isPro;
  final String? propertyId;
  final String? reason;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
  PaymentMethod _selectedMethod = PaymentMethod.wave;
  late final TextEditingController _phoneController;
  bool _isLoading = false;
  bool _hasLaunchedPayment = false;

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    _phoneController = TextEditingController(text: currentUser?.phone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _initiatePayment() async {
    final payerPhone = _phoneController.text.trim();
    if (payerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir votre numéro de téléphone.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repository = ref.read(paymentRepositoryProvider);
      final result = await repository.createSubscription(
        paymentMethod: _selectedMethod,
        payerPhone: payerPhone,
      );

      final uri = Uri.parse(result.redirectUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLaunchedPayment = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  Future<void> _verifyAndClose() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).refreshProfile();
      ref.invalidate(userSubscriptionStatusProvider);
      if (widget.propertyId != null) {
        ref.invalidate(
          canContactProvider((propertyId: widget.propertyId, ownerId: null)),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statut d\'abonnement mis à jour avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.isPro ? 3000 : 1000;
    final planLabel = widget.isPro ? 'Abonnement Bailleur / Agent' : 'Abonnement Client';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planLabel,
                        style: AppTextStyles.h3,
                      ),
                      Text(
                        '$price FCFA / mois',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isPro
                        ? 'Les réservations sont gratuites pour vos clients, mais un abonnement actif est requis pour les contacter et discuter avec eux.'
                        : 'Le bailleur de ce bien n\'ayant pas d\'abonnement actif, un abonnement de 1 000 FCFA / mois est requis pour pouvoir le contacter.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (widget.isPro) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Row(
                      children: [
                        Icon(Icons.verified, color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Badge de certification automatique inclus.',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Mode de paiement Mobile Money',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PaymentMethod.values.map((method) {
                final isSelected = _selectedMethod == method;
                return ChoiceChip(
                  label: Text(method.label),
                  selected: isSelected,
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedMethod = method);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Numéro de téléphone de paiement',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+225 07 00 00 00 00',
                prefixIcon: const Icon(Icons.phone_android_outlined, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!_hasLaunchedPayment) ...[
              PrimaryButton(
                label: 'Payer $price FCFA avec ${_selectedMethod.label}',
                isLoading: _isLoading,
                onPressed: _initiatePayment,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Paiement ouvert dans votre application / navigateur. Cliquez ci-dessous une fois validé.',
                        style: TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'J\'ai validé mon paiement',
                isLoading: _isLoading,
                onPressed: _verifyAndClose,
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: TextButton(
                  onPressed: _initiatePayment,
                  child: const Text('Relancer le paiement'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

