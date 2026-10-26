import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/ota_and_remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';

Future<bool?> showSubscriptionModal(
  BuildContext context, {
  bool isPro = false,
  UserRole? role,
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
      role: role,
      propertyId: propertyId,
      reason: reason,
    ),
  );
}

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({
    required this.isPro,
    this.role,
    this.propertyId,
    this.reason,
  });

  final bool isPro;
  final UserRole? role;
  final String? propertyId;
  final String? reason;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet>
    with WidgetsBindingObserver {
  PaymentMethod _selectedMethod = PaymentMethod.wave;
  bool _isLoading = false;
  bool _hasLaunchedPayment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasLaunchedPayment && !_isLoading) {
      _verifyAndClose(silentIfPending: true);
    }
  }

  Future<void> _initiatePayment() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(paymentRepositoryProvider);
      final result = await repository.createSubscription(
        paymentMethod: _selectedMethod,
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

  Future<void> _verifyAndClose({bool silentIfPending = false}) async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(paymentRepositoryProvider);
      var status = await repository.getSubscriptionStatus();

      // Si le statut n'est pas encore actif, patienter brièvement pour laisser
      // le temps à la passerelle Jèko d'enregistrer la transaction
      if (!status.hasActiveSubscription) {
        await Future.delayed(const Duration(seconds: 2));
        status = await repository.getSubscriptionStatus();
      }

      if (!status.hasActiveSubscription) {
        if (mounted) {
          setState(() => _isLoading = false);
          if (!silentIfPending) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Paiement non encore détecté. Si vous venez d\'effectuer le paiement, veuillez patienter quelques secondes puis réessayer.',
                ),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
        return;
      }

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
            content: Text('Forfait activé avec succès ! Vous pouvez planifier vos visites et contacter les propriétaires.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silentIfPending) {
          showErrorSnackbar(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final remoteConfig = ref.watch(remoteAppConfigProvider).valueOrNull ?? const RemoteAppConfig();
    final effectiveRole = widget.role ??
        currentUser?.role ??
        (widget.isPro ? UserRole.bailleur : UserRole.client);

    final String planLabel;
    final int price;
    final String description;
    final String badgePerk;

    if (effectiveRole == UserRole.bailleur) {
      planLabel = 'Pack Bailleur - Visites & Baux';
      price = remoteConfig.proPriceFcfa;
      description =
          'En tant que propriétaire ou bailleur, ce forfait professionnel couvre la mise en relation avec les candidats locataires, la planification des visites physiques de vos biens et la finalisation des baux.';
      badgePerk = 'Badge Bailleur certifié, planification de visites et gestion locative.';
    } else if (effectiveRole == UserRole.agent) {
      planLabel = 'Pack Agent - Visites & Mandats';
      price = remoteConfig.proPriceFcfa;
      description =
          'En tant qu\'agent immobilier, ce forfait professionnel couvre l\'organisation des visites sur le terrain avec les clients et l\'intermédiation pour la conclusion des baux.';
      badgePerk = 'Badge Agent certifié, diffusion d\'annonces et visites de biens.';
    } else {
      planLabel = 'Pass Visites & Mise en Relation';
      price = remoteConfig.clientPriceFcfa;
      description =
          'Ce forfait vous permet de planifier des visites physiques des logements sur le terrain, d\'échanger directement avec les propriétaires et d\'accéder aux contacts pour votre emménagement.';
      badgePerk = 'Visites de biens sur le terrain et mise en relation directe illimitées pendant 30 jours.';
    }

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
                    description,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.verified, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          badgePerk,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: PaymentMethod.values
                  .where((m) => remoteConfig.enabledPaymentMethods.isEmpty ||
                      remoteConfig.enabledPaymentMethods.contains(m.code))
                  .map((method) {
                final isSelected = _selectedMethod == method;
                return InkWell(
                  onTap: () => setState(() => _selectedMethod = method),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? method.brandColor.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected ? method.brandColor : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            method.assetPath,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            method.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, size: 16, color: method.brandColor),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (!_hasLaunchedPayment) ...[
              PrimaryButton(
                label: 'Payer',
                backgroundColor: _selectedMethod.brandColor,
                textColor: _selectedMethod.brandTextColor,
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

