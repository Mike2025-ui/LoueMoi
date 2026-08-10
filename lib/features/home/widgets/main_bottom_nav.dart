import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_providers.dart';

/// Shell de navigation principal : bottom bar 5 items + FAB central "+"
/// (Menu / Favoris / Publier / Reserves / Profil), conforme aux captures.
/// Les icônes sont les visuels réels fournis (assets/icons), teintées selon
/// l'état actif/inactif. Le FAB "Publier" n'apparaît que pour un agent —
/// seul un agent peut créer une annonce (permission appliquée côté Django,
/// ceci n'est qu'une politesse de navigation, pas la vraie barrière).
class MainBottomNav extends ConsumerWidget {
  const MainBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    _NavItem(asset: AppAssets.navMenu, label: 'Menu'),
    _NavItem(asset: AppAssets.navFavoris, label: 'Favoris'),
    null,
    _NavItem(asset: AppAssets.navReserves, label: 'Reserves'),
    _NavItem(asset: AppAssets.navProfil, label: 'Profil'),
  ];

  void _onTap(int index) {
    if (index == 2) return;
    final branchIndex = index < 2 ? index : index - 1;
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBranch = navigationShell.currentIndex;
    final isAgent = ref.watch(authControllerProvider).valueOrNull?.isAgent ?? false;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: isAgent
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.publish),
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.add, color: AppColors.white, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.white,
        elevation: 0,
        child: Container(
          height: AppSizes.bottomNavHeight,
          decoration: const BoxDecoration(boxShadow: AppShadows.bottomBar),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              if (item == null) return const SizedBox(width: 40);
              final navIndex = index < 2 ? index : index - 1;
              final isActive = navIndex == currentBranch;
              return _NavButton(
                item: item,
                isActive: isActive,
                onTap: () => _onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.asset, required this.label});
  final String asset;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.isActive, required this.onTap});

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              child: Image.asset(item.asset, width: 24, height: 24),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
