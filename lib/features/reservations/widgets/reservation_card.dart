import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/property_image.dart';
import '../../../core/widgets/status_badge.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';
import '../models/reservation.dart';
import '../providers/reservation_providers.dart';

class ReservationCard extends ConsumerWidget {
  const ReservationCard({super.key, required this.reservation, required this.onTap});

  final Reservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyAsync = ref.watch(propertyByIdProvider(reservation.propertyId));

    return propertyAsync.when(
      data: (property) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: InkWell(
                  onTap: onTap,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: PropertyImage(
                          property.coverImage,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                StatusBadge.category(property.category),
                                property.transactionType == TransactionType.location
                                    ? StatusBadge.location()
                                    : StatusBadge.vente(),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(property.title, style: AppTextStyles.bodyMedium),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 2),
                                Text(property.locationLabel, style: AppTextStyles.small),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  Formatters.shortDate(reservation.createdAt),
                                  style: AppTextStyles.small,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${Formatters.priceWithoutSuffix(reservation.rent)}fcfa',
                              style: AppTextStyles.link,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _ActionRow(reservation: reservation),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (reservation.status) {
      case ReservationStatus.enCours:
        return InkWell(
          onTap: () async {
            try {
              await cancelReservation(ref, reservation.id);
            } catch (e) {
              if (context.mounted) showErrorSnackbar(context, e);
            }
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: Text(
                'Annuler',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      case ReservationStatus.accomplie:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
                SizedBox(width: 6),
                Text('Accomplies',
                    style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      case ReservationStatus.annulee:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
                SizedBox(width: 6),
                Text('Annuler',
                    style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
    }
  }
}
