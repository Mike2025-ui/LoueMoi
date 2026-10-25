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
import '../../notifications/providers/notification_providers.dart';

/// Barre latérale de navigation pour la version Web Desktop / Tablette.
/// Regroupe TOUS les boutons et menus d'action à gauche, séparés par une barre
/// verticale nette du flux des annonces situé à droite.
class WebSidebarNav extends ConsumerWidget {
  const WebSidebarNav({
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
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final canPublish = user?.canOwnProperties ?? false;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          right: BorderSide(
            color: AppColors.border.withValues(alpha: 0.9),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Logo & Badge WEB en haut à gauche
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: InkWell(
                onTap: () => onTap(0),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Row(
                  children: [
                    const AppLogo(iconSize: 38),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LoueMoi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ESPACE WEB',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 12),

            // 2. Tous les boutons de navigation verticaux (à gauche)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _SidebarNavItem(
                    icon: Icons.home_rounded,
                    label: 'Accueil',
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  const SizedBox(height: 4),
                  _SidebarNavItem(
                    icon: Icons.favorite_rounded,
                    label: 'Favoris',
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  const SizedBox(height: 4),
                  _SidebarNavItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Réservations',
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  const SizedBox(height: 4),
                  _SidebarNavItem(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    isActive: currentIndex == 3,
                    badgeCount: unreadMessages,
                    onTap: () => onTap(3),
                  ),
                  const SizedBox(height: 4),
                  _SidebarNavItem(
                    icon: Icons.notifications_rounded,
                    label: 'Alertes',
                    isActive: false,
                    badgeCount: unreadNotifs,
                    onTap: () => context.push(AppRoutes.notifications),
                  ),
                  const SizedBox(height: 4),
                  _SidebarNavItem(
                    icon: Icons.person_rounded,
                    label: 'Mon Profil',
                    isActive: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // 3. Boutons d'action principaux de l'application
                  // Bouton "Publier un bien"
                  ElevatedButton.icon(
                    onPressed: () {
                      if (user == null) {
                        context.push(AppRoutes.login);
                      } else if (canPublish) {
                        context.push(AppRoutes.publish);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Réservé aux bailleurs et agents certifiés.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_circle, size: 20),
                    label: const Text(
                      'Publier un bien',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bouton "Obtenir l'App Mobile / Télécharger l'APK"
                  OutlinedButton.icon(
                    onPressed: () => showDownloadAppModal(context),
                    icon: const Icon(Icons.smartphone_rounded, size: 20),
                    label: const Text(
                      'Obtenir l’App APK',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Carte utilisateur en bas de la barre gauche
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: user != null
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: user.photo != null
                              ? NetworkImage(buildMediaUrl(user.photo!))
                              : null,
                          onBackgroundImageError: user.photo != null
                              ? (exception, stackTrace) {}
                              : null,
                          child: user.photo == null
                              ? Text(
                                  user.firstName.isNotEmpty
                                      ? user.firstName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.isAgent
                                    ? 'Agent Immobilier'
                                    : (user.isBailleur ? 'Bailleur' : 'Client'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Connectez-vous pour profiter de tous les services',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => context.push(AppRoutes.login),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: const Text('Connexion', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

