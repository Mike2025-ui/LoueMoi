import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/web_download_app_dialog.dart';
import '../../auth/providers/auth_providers.dart';
import '../../messaging/providers/message_providers.dart';
import '../../notifications/providers/notification_providers.dart';

/// Barre latérale de navigation pour la version Web Desktop / Tablette.
/// Regroupe les boutons de navigation à gauche avec les mêmes icônes que l'application mobile,
/// séparés par une barre verticale nette du contenu affiché à droite.
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

    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 1024 ? 220.0 : 240.0;

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          right: BorderSide(
            color: AppColors.border.withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(1, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Logo épuré en haut (sans texte noir ni badge)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: InkWell(
                  onTap: () => onTap(0),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: const AppLogo(iconSize: 42),
                ),
              ),
            ),

            const Divider(height: 1, indent: 16, endIndent: 16),
            const SizedBox(height: 10),

            // 2. Boutons de navigation avec les MÊMES icônes que l'APK
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _SidebarNavItem(
                    asset: AppAssets.navMenu,
                    label: 'Menu',
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  const SizedBox(height: 3),
                  _SidebarNavItem(
                    asset: AppAssets.navFavoris,
                    label: 'Favoris',
                    isActive: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  const SizedBox(height: 3),
                  _SidebarNavItem(
                    asset: AppAssets.navReserves,
                    label: 'Réservations',
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  const SizedBox(height: 3),
                  _SidebarNavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    isActive: currentIndex == 3,
                    badgeCount: unreadMessages,
                    onTap: () => onTap(3),
                  ),
                  const SizedBox(height: 3),
                  _SidebarNavItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    isActive: currentIndex == 5,
                    badgeCount: unreadNotifs,
                    onTap: () => onTap(5),
                  ),
                  const SizedBox(height: 3),
                  _SidebarNavItem(
                    asset: AppAssets.navProfil,
                    label: 'Profil',
                    isActive: currentIndex == 4,
                    onTap: () => onTap(4),
                  ),

                  const SizedBox(height: 18),
                  const Divider(height: 1, indent: 6, endIndent: 6),
                  const SizedBox(height: 16),

                  // 3. Bouton "Publier un bien" : affiché UNIQUEMENT pour les autorisés (bailleurs / agents)
                  if (canPublish) ...[
                    ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.publish),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text(
                        'Publier un bien',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4. Bouton "Télécharger l'APK" ultra-attractif et moderne
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => showDownloadAppModal(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0F766E),
                              Color(0xFF009688),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF009688).withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.android_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'APPLICATION MOBILE',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'Télécharger l’APK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 5. Carte utilisateur compacte et responsive en bas
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: user != null
                  ? Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
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
                                    fontSize: 13,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.isAgent
                                    ? 'Agent'
                                    : (user.isBailleur ? 'Bailleur' : 'Client'),
                                style: const TextStyle(
                                  fontSize: 10.5,
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
                          'Connectez-vous pour accéder à vos services',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ElevatedButton(
                          onPressed: () => context.push(AppRoutes.login),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: const Text('Connexion', style: TextStyle(fontSize: 11.5)),
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

/// Élément de navigation de la barre latérale qui supporte soit une icône Material
/// soit une icône Asset (exactement identique à la BottomNavBar du mobile).
class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    this.icon,
    this.asset,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  }) : assert(icon != null || asset != null);

  final IconData? icon;
  final String? asset;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            asset != null
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                    child: Image.asset(asset!, width: 20, height: 20),
                  )
                : Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 10,
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
