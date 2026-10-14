import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/reservation.dart';
import '../providers/reservation_providers.dart';
import '../widgets/reservation_card.dart';

class ReservationsListScreen extends StatefulWidget {
  const ReservationsListScreen({super.key});

  @override
  State<ReservationsListScreen> createState() => _ReservationsListScreenState();
}

class _ReservationsListScreenState extends State<ReservationsListScreen>
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Réservations'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
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
        ),
      ),
      body: TabBarView(
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

class _ReservationsTab extends ConsumerWidget {
  const _ReservationsTab({required this.status});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(reservationsByStatusProvider(status));

    return Container(
      color: AppColors.surfaceMuted,
      child: reservationsAsync.when(
        skipLoadingOnReload: true,
        data: (reservations) {
          if (reservations.isEmpty) {
            return const Center(
              child: Text('Aucune réservation', style: AppTextStyles.caption),
            );
          }
          return ListView.builder(
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
        error: (e, _) => const Center(
          child: Text('Impossible de charger les réservations.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}
