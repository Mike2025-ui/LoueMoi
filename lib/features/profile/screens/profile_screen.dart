import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/providers/auth_providers.dart';
import '../../payments/widgets/subscription_modal.dart';
import '../widgets/profile_menu_tile.dart';

/// Flux "Supprimer mon compte" (décision métier : désactivation, jamais de
/// suppression physique — voir AuthController.deactivateAccount) :
/// confirmation explicite, puis authentification supplémentaire par mot de
/// passe avant toute action, jamais un simple bouton qui agit directement.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: const Text('Supprimer mon compte ?'),
      content: const Text(
        'Votre compte sera désactivé et vous serez déconnecté. Vos annonces, réservations, '
        'messages et avis restent conservés — contactez-nous si vous souhaitez leur suppression '
        'définitive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Continuer', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final passwordController = TextEditingController();
  var isSubmitting = false;
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (statefulContext, setDialogState) {
        Future<void> submit() async {
          final password = passwordController.text;
          if (password.isEmpty) {
            setDialogState(() => errorText = 'Mot de passe requis.');
            return;
          }
          setDialogState(() {
            isSubmitting = true;
            errorText = null;
          });
          try {
            await ref.read(authControllerProvider.notifier).deactivateAccount(password);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            if (context.mounted) context.go(AppRoutes.login);
          } catch (e) {
            setDialogState(() {
              isSubmitting = false;
              errorText = 'Mot de passe incorrect.';
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: const Text('Confirmez votre mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Mot de passe',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => isSubmitting ? null : submit(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: isSubmitting ? null : submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Supprimer mon compte', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        );
      },
    ),
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              const Text('Profil', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: AppSizes.avatarLg / 2,
                backgroundColor: AppColors.primary,
                backgroundImage: user?.photo != null
                    ? NetworkImage(buildMediaUrl(user!.photo!))
                    : null,
                child: user?.photo == null
                    ? const Icon(Icons.person, size: 48, color: AppColors.white)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(user?.fullName ?? 'Utilisateur', style: AppTextStyles.h3),
                  if (user?.isVerifiedUser ?? false) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: AppColors.primary, size: 20),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(user?.phone ?? '', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xl),
              // Pas d'entrée "Messages" ici : la maquette n'en montre aucune
              // sur cet écran (l'onglet Messages de la bottom navigation
              // reste le seul accès aux conversations, inchangé).
              ProfileMenuTile(
                icon: Icons.receipt_long_outlined,
                label: 'Propriétés contactées',
                onTap: () => context.push(AppRoutes.contactedProperties),
              ),
              ProfileMenuTile(
                icon: Icons.person_add_alt_outlined,
                label: 'Informations personnelles',
                onTap: () => context.push(AppRoutes.personalInfo),
              ),
              ProfileMenuTile(
                icon: Icons.workspace_premium_outlined,
                label: (user?.hasActiveSubscription ?? false)
                    ? 'Mon abonnement (Actif)'
                    : 'Abonnement LoueMoi',
                onTap: () {
                  showSubscriptionModal(
                    context,
                    isPro: user?.canOwnProperties ?? false,
                    role: user?.role,
                  );
                },
              ),
              if (user?.isAgent ?? false)
                ProfileMenuTile(
                  icon: Icons.groups_outlined,
                  label: 'Mon espace agent',
                  onTap: () => context.push(AppRoutes.agentSpace),
                ),
              if (user?.isBailleur ?? false)
                ProfileMenuTile(
                  icon: Icons.home_work_outlined,
                  label: 'Mon espace bailleur',
                  onTap: () => context.push(AppRoutes.bailleurSpace),
                ),
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: () => ref.read(authControllerProvider.notifier).logout().then(
                      (_) {
                        if (context.mounted) context.go(AppRoutes.login);
                      },
                    ),
                child: const Text(
                  'Deconnexion',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => _confirmDeleteAccount(context, ref),
                child: const Text(
                  'Supprimer mon compte',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
