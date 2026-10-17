import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/user_role.dart';
import '../providers/auth_providers.dart';

class PendingActivationScreen extends ConsumerStatefulWidget {
  const PendingActivationScreen({super.key});

  @override
  ConsumerState<PendingActivationScreen> createState() =>
      _PendingActivationScreenState();
}

class _PendingActivationScreenState
    extends ConsumerState<PendingActivationScreen> {
  bool _isRequesting = false;
  bool _isChecking = false;

  Future<void> _handleRequestActivation() async {
    setState(() => _isRequesting = true);
    try {
      await ref.read(authControllerProvider.notifier).requestActivation();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Votre demande d'activation a bien été transmise à l'administrateur.",
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    try {
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isChecking = false);

    final user = ref.read(authControllerProvider).valueOrNull;
    if (user != null && user.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Félicitations ! Votre compte a été activé."),
          backgroundColor: Colors.green,
        ),
      );
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Votre demande d'activation est toujours en cours de validation par l'administrateur.",
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    final isLoading = _isRequesting || _isChecking;

    if (user == null) {
      if (authState.isLoading) {
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Session non disponible"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text("Se connecter"),
              ),
            ],
          ),
        ),
      );
    }

    final roleLabel = user.role == UserRole.bailleur
        ? 'Compte Bailleur'
        : 'Compte Agent immobilier';
    final hasRequested = user.activationRequested;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppLogo(iconSize: 40),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      roleLabel,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: hasRequested
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasRequested
                          ? Icons.hourglass_top_rounded
                          : Icons.admin_panel_settings_outlined,
                      size: 48,
                      color: hasRequested
                          ? const Color(0xFFD97706)
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    hasRequested
                        ? "Votre demande d'activation est en cours"
                        : "Activation de votre compte requise",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!hasRequested) ...[
                          Text(
                            "Bonjour ${user.fullName},",
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            "Afin de garantir la sécurité, la fiabilité et l’authenticité des annonces sur LoueMoi, les comptes Bailleur et Agent sont activés par un administrateur avant de pouvoir accéder à l'application.\n\nVeuillez transmettre votre demande d'activation à notre équipe en cliquant sur le bouton ci-dessous.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ] else ...[
                          Row(
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  "Demande transmise au tableau de bord",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            "Votre demande d'activation est actuellement entre les mains de notre équipe d'administration.",
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFF25D366),
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Notification d'activation par WhatsApp :",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.whatsapp.isNotEmpty
                                        ? user.whatsapp
                                        : user.phone,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    "Dès que l'administrateur aura activé votre compte, vous recevrez une confirmation sur ce numéro WhatsApp.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!hasRequested)
                    PrimaryButton(
                      label: "Demander l'activation du compte",
                      isLoading: isLoading,
                      onPressed: _handleRequestActivation,
                    )
                  else
                    PrimaryButton(
                      label: "Vérifier le statut d'activation",
                      isLoading: isLoading,
                      onPressed: _checkStatus,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: isLoading ? null : _logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    label: const Text(
                      'Se déconnecter',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

