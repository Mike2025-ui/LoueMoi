import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/providers/auth_providers.dart';
import '../../properties/models/agent.dart';
import '../../properties/widgets/agent_card.dart';
import '../widgets/profile_menu_tile.dart';

/// Espace agent : utilise l'utilisateur réellement connecté (jamais de
/// données mock codées en dur) — is_verified vient de agent_profile, jamais
/// auto-déclarable par l'agent lui-même.
class AgentSpaceScreen extends ConsumerWidget {
  const AgentSpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final profile = user?.agentProfile;
    final isVerified = profile?.isVerified ?? false;

    final agent = Agent(
      id: user?.id ?? '',
      firstName: user?.firstName ?? 'Agent',
      lastName: user?.lastName ?? '',
      phone: user?.phone ?? '',
      whatsapp: profile?.whatsapp.isNotEmpty == true ? profile!.whatsapp : (user?.whatsapp ?? ''),
      photo: user?.photo,
      isVerified: isVerified,
      rating: profile?.rating ?? 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: AgentCard(agent: agent),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: user?.photo != null
                          ? NetworkImage(buildMediaUrl(user!.photo!))
                          : null,
                      child: user?.photo == null
                          ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                          : null,
                    ),
                    // Badge "vérifié" uniquement si agent_profile.is_verified
                    // est vrai côté serveur — jamais auto-déclaré.
                    if (isVerified)
                      const Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.check, size: 12, color: AppColors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.shortName, style: AppTextStyles.bodyMedium),
                      Text(agent.fullName, style: AppTextStyles.caption),
                      const Text('Agent immobilier', style: AppTextStyles.small),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showComingSoonSnackbar(context, 'Modifier le profil'),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  label: const Text('Modifier', style: AppTextStyles.link),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            ProfileMenuTile(
              icon: Icons.apartment_outlined,
              label: 'Mes annonces',
              onTap: () => context.push(AppRoutes.myProperties),
            ),
            ProfileMenuTile(
              icon: Icons.assignment_outlined,
              label: 'Mes réservations',
              onTap: () => context.push(AppRoutes.reservationsList),
            ),
            ProfileMenuTile(
              icon: Icons.sell_outlined,
              label: 'Propriétés vendues',
              onTap: () => showComingSoonSnackbar(context, 'Propriétés vendues'),
            ),
            ProfileMenuTile(
              icon: Icons.find_in_page_outlined,
              label: 'Reconduire un bien',
              onTap: () => showComingSoonSnackbar(context, 'Reconduire un bien'),
            ),
            ProfileMenuTile(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () => context.push(AppRoutes.agentDashboard),
            ),
            ProfileMenuTile(
              icon: Icons.verified_outlined,
              label: 'Certification',
              onTap: () => showComingSoonSnackbar(context, 'Certification'),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: TextButton(
                onPressed: () => _confirmDeletePage(context),
                child: const Text(
                  'Supprimer la page',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Supprimer la page ?'),
        content: const Text(
          'Cette action est irréversible. Votre espace agent et vos annonces seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              showComingSoonSnackbar(context, 'Suppression de la page');
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
