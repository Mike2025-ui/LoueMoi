import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/property_image.dart';
import '../../../core/widgets/status_badge.dart';
import '../../properties/models/property.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';
import '../../properties/widgets/property_details_table.dart';
import '../providers/reservation_providers.dart';

class ReservationSummaryScreen extends ConsumerWidget {
  const ReservationSummaryScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyAsync = ref.watch(propertyByIdProvider(propertyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reservation')),
      body: propertyAsync.when(
        skipLoadingOnReload: true,
        data: (property) => _Summary(property: property),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger l’annonce.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}

class _Summary extends ConsumerStatefulWidget {
  const _Summary({required this.property});

  final Property property;

  @override
  ConsumerState<_Summary> createState() => _SummaryState();
}

class _SummaryState extends ConsumerState<_Summary> {
  bool _isSubmitting = false;

  Future<void> _reserve() async {
    setState(() => _isSubmitting = true);
    final property = widget.property;
    try {
      // Le total affiché ici n'est qu'un aperçu : Django recalcule et
      // valide (propriété toujours disponible ?) côté serveur, qui reste la
      // seule source de vérité.
      await createReservation(
        ref,
        propertyId: property.id,
        rent: property.price,
        deposit: property.deposit ?? 0,
        advance: property.advance ?? 0,
      );
      if (!mounted) return;
      context.push(AppRoutes.reservationConfirmation);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showErrorSnackbar(context, e);
      // La propriété a pu devenir indisponible entre-temps (déjà réservée) :
      // on rafraîchit son état pour refléter "Occupée" si l'utilisateur revient.
      ref.invalidate(propertyByIdProvider(property.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    // Total toujours recalculé, jamais codé en dur.
    final total = property.reservationTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: PropertyImage(
                  property.coverImage,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusBadge.category(property.type.label),
                    const SizedBox(height: 4),
                    Text(property.title, style: AppTextStyles.h3),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(property.locationLabel, style: AppTextStyles.caption),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(Formatters.price(property.price), style: AppTextStyles.priceSm),
                        property.transactionType == TransactionType.location
                            ? StatusBadge.location()
                            : StatusBadge.vente(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          const Text('Caracteristiques', style: AppTextStyles.caption),
          PropertyDetailsTable(property: property),
          const Divider(height: AppSpacing.xl),
          _PriceRow(label: 'Loyer', value: property.price),
          _PriceRow(label: 'Caution', value: property.deposit ?? 0),
          _PriceRow(label: 'Avance', value: property.advance ?? 0),
          const Divider(height: AppSpacing.xl),
          _PriceRow(label: 'Total', value: total, isBold: true),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Reserver',
            isLoading: _isSubmitting,
            onPressed: _reserve,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.value, this.isBold = false});

  final String label;
  final double value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final style = isBold
        ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)
        : AppTextStyles.caption;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            '${Formatters.priceWithoutSuffix(value)}f',
            style: isBold ? style : AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
