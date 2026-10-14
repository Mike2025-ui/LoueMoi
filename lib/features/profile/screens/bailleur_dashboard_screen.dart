import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/bailleur_providers.dart';

/// GET /api/bailleur/dashboard/ — chiffres calculés côté Django, jamais
/// codés en dur ni recalculés côté Flutter. Même présentation que
/// AgentDashboardScreen (voir profile/screens/agent_dashboard_screen.dart) —
/// rôle indépendant, mêmes indicateurs, même design.
class BailleurDashboardScreen extends ConsumerWidget {
  const BailleurDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(bailleurDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Statistiques')),
      body: dashboardAsync.when(
        data: (dashboard) => RefreshIndicator(
          onRefresh: () => ref.refresh(bailleurDashboardProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Voir agent_dashboard_screen.dart pour l'explication
                // complète : childAspectRatio fixe provoquait "BOTTOM
                // OVERFLOWED BY 6.7 PIXELS" sur téléphone réel (métriques de
                // police différentes du simulateur) — remplacé par des Row
                // de cartes en Expanded, hauteur intrinsèque au contenu.
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.apartment_outlined,
                        value: '${dashboard.propertiesCount}',
                        label: 'Mes biens',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle_outline,
                        value: '${dashboard.availableCount}',
                        label: 'Disponibles',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.lock_clock_outlined,
                        value: '${dashboard.occupiedCount}',
                        label: 'Occupés',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.assignment_outlined,
                        value: '${dashboard.reservationsCount}',
                        label: 'Réservations',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.favorite_outline,
                        value: '${dashboard.favoritesReceived}',
                        label: 'Favoris reçus',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.visibility_outlined,
                        value: '${dashboard.viewsCount}',
                        label: 'Vues',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.chat_bubble_outline,
                        value: '${dashboard.messagesCount}',
                        label: 'Messages',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star_border,
                        value: dashboard.averageRating.toStringAsFixed(1),
                        label: 'Note moyenne',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger les statistiques.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.h3),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
