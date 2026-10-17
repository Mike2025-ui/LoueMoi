import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/reservation.dart';
import '../providers/reservation_providers.dart';
import '../widgets/reservation_card.dart';

class ReservationsListScreen extends ConsumerStatefulWidget {
  const ReservationsListScreen({super.key});

  @override
  ConsumerState<ReservationsListScreen> createState() => _ReservationsListScreenState();
}

class _ReservationsListScreenState extends ConsumerState<ReservationsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Réservations'),
        automaticallyImplyLeading: false,
        bottom: currentUser != null
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'En cours'),
                  Tab(text: 'Accomplies'),
                  Tab(text: 'Annulées'),
                ],
              )
            : null,
      ),
      body: currentUser == null
          ? const _UnauthenticatedView()
          : TabBarView(
              controller: _tabController,
              children: const [
                _ReservationsTab(status: ReservationStatus.enCours),
                _ReservationsTab(status: ReservationStatus.accomplie),
                _ReservationsTab(status: ReservationStatus.annulee),
              ],
            ),
    );
  }
}

class _UnauthenticatedView extends StatelessWidget {
  const _UnauthenticatedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Connectez-vous pour voir vos réservations',
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Suivez le statut de vos réservations en cours, accomplies ou annulées en temps réel.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.login),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Se connecter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationsTab extends ConsumerWidget {
  const _ReservationsTab({required this.status});

  final ReservationStatus status;

  String get _emptyTitle => switch (status) {
        ReservationStatus.enCours => 'Aucune réservation en cours',
        ReservationStatus.accomplie => 'Aucune réservation accomplie',
        ReservationStatus.annulee => 'Aucune réservation annulée',
      };

  IconData get _emptyIcon => switch (status) {
        ReservationStatus.enCours => Icons.assignment_outlined,
        ReservationStatus.accomplie => Icons.check_circle_outline,
        ReservationStatus.annulee => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(reservationsByStatusProvider(status));

    return Container(
      color: AppColors.surfaceMuted,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(reservationsListProvider.future),
        child: reservationsAsync.when(
          skipLoadingOnReload: true,
          data: (reservations) {
            if (reservations.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_emptyIcon, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                        const SizedBox(height: AppSpacing.md),
                        Text(_emptyTitle, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: reservations.length,
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                return ReservationCard(
                  reservation: reservation,
                  onTap: () =>
                      context.push(AppRoutes.propertyDetailPath(reservation.propertyId)),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 100),
              Center(
                child: Text('Impossible de charger les réservations.', style: AppTextStyles.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
