import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_providers.dart';
import '../../filters/providers/filter_providers.dart';
import '../../messaging/providers/message_providers.dart';

/// Shell de navigation principal : bottom bar + FAB central "+"
/// (Menu / Favoris / Publier / Réservations / Conversations / Profil), conforme
/// aux captures. Les icônes Menu/Favoris/Réservations/Profil sont les visuels
/// réels fournis (assets/icons) ; Conversations réutilise une icône
/// Material (aucun asset PNG dédié fourni pour cet onglet) mais avec le
/// même traitement visuel (taille, couleur active/inactive, style de
/// label) pour rester cohérent avec le reste de la barre. Le FAB "Publier"
/// n'apparaît que pour un agent ou un bailleur (deux rôles indépendants,
/// tous deux habilités à publier — voir User.canOwnProperties), jamais pour
/// un client. Permission appliquée côté Django, ceci n'est qu'une politesse
/// de navigation, pas la vraie barrière.
class MainBottomNav extends ConsumerWidget {
  const MainBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  // Plus de "null" en 3e position : le trou réservé au FAB n'est plus
  // représenté comme un élément de cette liste (voir build(), qui le
  // positionne désormais autrement) — chaque entrée correspond directement
  // à une branche de navigationShell, dans l'ordre.
  static const _items = [
    _NavItem(asset: AppAssets.navMenu, label: 'Menu'),
    _NavItem(asset: AppAssets.navFavoris, label: 'Favoris'),
    _NavItem(asset: AppAssets.navReserves, label: 'Réservations'),
    _NavItem(icon: Icons.chat_bubble_outline, label: 'Messages'),
    _NavItem(asset: AppAssets.navProfil, label: 'Profil'),
  ];

  void _onTap(WidgetRef ref, int branchIndex) {
    if (branchIndex == 3) {
      ref.invalidate(conversationsProvider);
    }
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = navigationShell.currentIndex;
    final canPublish = ref.watch(authControllerProvider).valueOrNull?.canOwnProperties ?? false;
    final unreadMessages = ref.watch(totalUnreadConversationsCountProvider);
    final isFiltersOpen = ref.watch(isFiltersSheetOpenProvider);
    final showPublishFab = canPublish && currentBranch == 0 && !isFiltersOpen;

    Widget navButton(int branchIndex) {
      final item = _items[branchIndex];
      // "Messages" est le seul onglet avec badge non-lu — les autres
      // (Menu/Favoris/Réservations/Profil) n'ont jamais porté de badge,
      // ce comportement n'est pas étendu ici sans raison métier.
      final badgeCount = item.label == 'Messages' ? unreadMessages : 0;
      return Expanded(
        child: _NavButton(
          item: item,
          isActive: branchIndex == currentBranch,
          badgeCount: badgeCount,
          onTap: () => _onTap(ref, branchIndex),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      floatingActionButton: showPublishFab
          ? FloatingActionButton(
              heroTag: 'publish_property_fab',
              onPressed: () => context.push(AppRoutes.publish),
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, color: AppColors.white, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.white,
        elevation: 0,
        padding: EdgeInsets.zero,
        child: Container(
          height: AppSizes.bottomNavHeight,
          decoration: const BoxDecoration(boxShadow: AppShadows.bottomBar),
          child: Row(
            children: [
              navButton(0),
              navButton(1),
              navButton(2),
              navButton(3),
              navButton(4),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({this.asset, this.icon, required this.label}) : assert(asset != null || icon != null);
  final String? asset;
  final IconData? icon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                item.asset != null
                    ? ColorFiltered(
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                        child: Image.asset(item.asset!, width: 24, height: 24),
                      )
                    : Icon(item.icon, size: 24, color: color),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            // FittedBox plutôt qu'un overflow ellipsis : sur un écran
            // étroit (~360dp), "Réservations"/"Messages"/"Favoris" ne
            // tenaient jamais dans la largeur d'un bouton (5 boutons +
            // l'encoche FAB) et s'affichaient tronqués en "Rése...",
            // "Mess...", "Favor..." — illisible et peu professionnel. Le
            // texte se réduit maintenant pour tenir en entier, jamais coupé.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
