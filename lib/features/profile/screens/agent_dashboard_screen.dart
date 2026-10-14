import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/agent_providers.dart';

/// GET /api/agent/dashboard/ — chiffres calculés côté Django, jamais codés
/// en dur ni recalculés côté Flutter.
class AgentDashboardScreen extends ConsumerWidget {
  const AgentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(agentDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Dashboard')),
      body: dashboardAsync.when(
        data: (dashboard) => RefreshIndicator(
          onRefresh: () => ref.refresh(agentDashboardProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Une grille à childAspectRatio fixe force chaque carte dans
                // une hauteur calculée, indépendante de son contenu réel :
                // sur un vrai téléphone (métriques de police/densité d'écran
                // différentes du simulateur), l'icône + les deux lignes de
                // texte ne tenaient plus dans cette hauteur imposée
                // ("BOTTOM OVERFLOWED BY 6.7 PIXELS", reproduit sur
                // appareil réel). Des Row de cartes en Expanded laissent
                // chaque carte prendre la hauteur dont son contenu a
                // réellement besoin — plus aucune hauteur n'est imposée.
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.apartment_outlined,
                        value: '${dashboard.propertiesCount}',
                        label: 'Mes annonces',
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
                        label: 'Occupées',
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
          child: Text('Impossible de charger le dashboard.', style: AppTextStyles.caption),
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
