import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/web_download_app_dialog.dart';
import '../../auth/providers/auth_providers.dart';
import '../../messaging/providers/message_providers.dart';

/// Barre de navigation supérieure pour la version Web Desktop / Tablette (inspirée de TikTok Web & Airbnb).
/// Remplace la barre du bas mobile (BottomNavigationBar) sur les écrans larges (>= 768px).
class WebHeaderNav extends ConsumerWidget {
  const WebHeaderNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final unreadMessages = ref.watch(totalUnreadConversationsCountProvider);
    final canPublish = user?.canOwnProperties ?? false;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                // 1. Logo & Marque
                InkWell(
                  onTap: () => onTap(0),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        const AppLogo(iconSize: 34),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'WEB',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.xl),

                // 2. Liens de navigation centraux
                Expanded(
                  child: Row(
                    children: [
                      _NavLink(
                        icon: Icons.home_rounded,
                        label: 'Accueil',
                        isActive: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      const SizedBox(width: 8),
                      _NavLink(
                        icon: Icons.favorite_rounded,
                        label: 'Favoris',
                        isActive: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      const SizedBox(width: 8),
                      _NavLink(
                        icon: Icons.calendar_month_rounded,
                        label: 'Réservations',
                        isActive: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                      const SizedBox(width: 8),
                      _NavLink(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Messages',
                        isActive: currentIndex == 3,
                        badgeCount: unreadMessages,
                        onTap: () => onTap(3),
                      ),
                    ],
                  ),
                ),

                // 3. Boutons d'action à droite (Bannière App mobile + Publier + Profil)
                Row(
                  children: [
                    // Bouton spécial TikTok Web : "Obtenir l'App / Télécharger l'APK"
                    OutlinedButton.icon(
                      onPressed: () => showDownloadAppModal(context),
                      icon: const Icon(Icons.install_mobile_rounded, size: 18),
                      label: const Text('Obtenir l’App Mobile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),

                    if (canPublish) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.push(AppRoutes.publish),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Publier un bien'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ],

                    const SizedBox(width: 16),

                    // Profil utilisateur
                    InkWell(
                      onTap: () => onTap(4),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: currentIndex == 4 ? AppColors.primary : AppColors.border,
                            width: currentIndex == 4 ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: user?.photo != null
                                  ? NetworkImage(buildMediaUrl(user!.photo!))
                                  : null,
                              onBackgroundImageError:
                                  user?.photo != null ? (exception, stackTrace) {} : null,
                              child: user?.photo == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 18,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                user?.firstName.isNotEmpty == true
                                    ? user!.firstName
                                    : 'Mon profil',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

