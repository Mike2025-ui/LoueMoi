import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/providers/auth_providers.dart';
import '../widgets/profile_menu_tile.dart';

/// Espace bailleur : même architecture que l'espace agent (AgentSpaceScreen)
/// — utilisateur réellement connecté, jamais de données codées en dur —
/// mais un rôle strictement indépendant : pas de profil professionnel
/// (agency_name/is_verified/rating n'existent que pour un agent), pas de
/// badge "vérifié".
class BailleurSpaceScreen extends ConsumerWidget {
  const BailleurSpaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Espace bailleur')),
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
                      onBackgroundImageError: user?.photo != null ? (_, __) {} : null,
                      child: user?.photo == null
                          ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                          : null,
                    ),
                    if (user?.isVerifiedUser ?? false)
                      const Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user?.fullName ?? 'Bailleur',
                              style: AppTextStyles.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user?.isVerifiedUser ?? false) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(user?.phone ?? '', style: AppTextStyles.caption),
                      const Text('Bailleur', style: AppTextStyles.small),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            ProfileMenuTile(
              icon: Icons.apartment_outlined,
              label: 'Mes biens',
              onTap: () => context.push(AppRoutes.bailleurProperties),
            ),
            ProfileMenuTile(
              icon: Icons.dashboard_outlined,
              label: 'Statistiques',
              onTap: () => context.push(AppRoutes.bailleurDashboard),
            ),
            ProfileMenuTile(
              icon: Icons.assignment_outlined,
              label: 'Mes réservations',
              // Route d'un autre onglet du shell : go(), jamais push() (voir
              // profile_screen.dart pour l'explication du crash évité).
              onTap: () => context.go(AppRoutes.reservationsList),
            ),
            ProfileMenuTile(
              icon: Icons.search,
              label: 'Trouver un agent',
              onTap: () => context.push(AppRoutes.agentSearch),
            ),
          ],
        ),
      ),
    );
  }
}
