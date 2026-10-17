import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/property_image.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_providers.dart';
import '../../properties/models/property.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';
import '../models/reservation.dart';
import '../providers/reservation_providers.dart';

class ReservationCard extends ConsumerWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    required this.onTap,
  });

  final Reservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyAsync = ref.watch(
      propertyByIdProvider(reservation.propertyId),
    );
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    // "Voir qui a réservé" : uniquement pertinent pour le propriétaire du
    // bien qui consulte une réservation faite par quelqu'un d'autre — un
    // client qui voit sa propre réservation n'a pas besoin de revoir ses
    // propres coordonnées.
    final client = reservation.client;
    final showClientInfo =
        client != null && currentUserId != null && currentUserId != client.id;

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
                                property.transactionType ==
                                        TransactionType.location
                                    ? StatusBadge.location()
                                    : StatusBadge.vente(),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              property.title,
                              style: AppTextStyles.bodyMedium,
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  property.locationLabel,
                                  style: AppTextStyles.small,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
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
                            if (showClientInfo) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      client.phone.isEmpty
                                          ? 'Réservé par ${client.fullName}'
                                          : 'Réservé par ${client.fullName} · ${client.phone}',
                                      style: AppTextStyles.small,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _ActionRow(
                reservation: reservation,
                property: showClientInfo ? property : null,
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 96,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Annonce indisponible', style: AppTextStyles.bodyMedium),
                Text(
                  '${Formatters.priceWithoutSuffix(reservation.rent)}fcfa',
                  style: AppTextStyles.link,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(Formatters.shortDate(reservation.createdAt), style: AppTextStyles.small),
              ],
            ),
            const Divider(height: AppSpacing.md),
            _ActionRow(reservation: reservation, property: null),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.reservation, required this.property});

  final Reservation reservation;

  /// Non-null uniquement quand l'utilisateur connecté est le propriétaire du
  /// bien (voir ReservationCard.showClientInfo) — c'est ce qui conditionne
  /// l'affichage de "Discuter"/"Marquer occupé", jamais visible pour le
  /// client qui a réservé.
  final Property? property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (reservation.status) {
      case ReservationStatus.enCours:
        // `property` n'est non-null que lorsque l'utilisateur connecté est
        // le propriétaire du bien (voir ReservationCard.showClientInfo) —
        // dans ce cas, seules ses propres actions (Discuter/Marquer occupé/
        // Valider) sont affichées. "Annuler" n'appartient qu'au client qui a
        // fait la réservation : le propriétaire ne doit jamais pouvoir
        // l'annuler depuis cette carte (règle métier), et le bouton ne doit
        // donc même pas lui être proposé — l'ancien code affichait les deux
        // rangées à la fois pour le propriétaire, ce qui lui offrait un
        // bouton "Annuler" qu'il n'aurait jamais dû voir.
        if (property != null) {
          return _OwnerActionsRow(
            reservation: reservation,
            property: property!,
          );
        }
        return _CancelButton(reservationId: reservation.id);
      case ReservationStatus.accomplie:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Accomplies',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      case ReservationStatus.annulee:
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.cancel_outlined,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Annulée',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              _DeleteReservationButton(reservationId: reservation.id),
            ],
          ),
        );
    }
  }
}

class _DeleteReservationButton extends ConsumerStatefulWidget {
  const _DeleteReservationButton({required this.reservationId});

  final String reservationId;

  @override
  ConsumerState<_DeleteReservationButton> createState() =>
      _DeleteReservationButtonState();
}

class _DeleteReservationButtonState
    extends ConsumerState<_DeleteReservationButton> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Supprimer la réservation ?'),
        content: const Text(
          'Cette réservation annulée sera définitivement supprimée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    try {
      await deleteReservation(ref, widget.reservationId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Réservation supprimée.')));
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.danger,
        ),
      );
    }
    return TextButton.icon(
      onPressed: _delete,
      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
      label: const Text(
        'Supprimer',
        style: TextStyle(
          color: AppColors.danger,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Bouton "Annuler" d'une réservation "en cours" — réservé au client qui l'a
/// faite (voir _ActionRow). État de chargement propre + garde anti-double-clic
/// (`_isCancelling`) : sans ça, un appui répété pendant l'attente réseau
/// pouvait déclencher plusieurs appels `cancel` en parallèle pour la même
/// réservation.
class _CancelButton extends ConsumerStatefulWidget {
  const _CancelButton({required this.reservationId});

  final String reservationId;

  @override
  ConsumerState<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends ConsumerState<_CancelButton> {
  bool _isCancelling = false;

  Future<void> _cancel() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      await cancelReservation(ref, widget.reservationId);
      // En cas de succès, cette carte est retirée de la liste "En cours" dès
      // que reservationsListProvider (invalidé par cancelReservation) se
      // recharge — pas besoin de mettre à jour un état local ici.
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: _isCancelling ? null : _cancel,
        // Pilule pleine (fond clair) au lieu d'un texte seul, pour
        // correspondre à la maquette — même paire de couleurs que
        // StatusBadge.category (primaryLight/primary), déjà utilisée
        // ailleurs dans l'app pour ce genre de pastille.
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Center(
            child: _isCancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Text(
                    'Annuler',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// "Discuter" + "Marquer occupé/disponible" — réservé au propriétaire du
/// bien (voir _ActionRow.property), pour qu'il puisse échanger avec le
/// client qui a réservé et faire suivre la disponibilité réelle du bien
/// sans passer par la fiche annonce.
class _OwnerActionsRow extends ConsumerStatefulWidget {
  const _OwnerActionsRow({required this.reservation, required this.property});

  final Reservation reservation;
  final Property property;

  @override
  ConsumerState<_OwnerActionsRow> createState() => _OwnerActionsRowState();
}

class _OwnerActionsRowState extends ConsumerState<_OwnerActionsRow> {
  bool _openingChat = false;
  bool _togglingStatus = false;
  bool _completingReservation = false;

  Future<void> _openChat() async {
    setState(() => _openingChat = true);
    try {
      final repository = ref.read(reservationRepositoryProvider);
      final conversationId = await repository.getOrCreateConversationId(
        widget.reservation.id,
      );
      if (!mounted) return;
      context.push(
        AppRoutes.conversationPath(conversationId),
        extra: {'participantName': widget.reservation.client?.fullName},
      );
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _toggleOccupied() async {
    final isLocation =
        widget.property.transactionType == TransactionType.location;
    final nextStatus = widget.property.status == PropertyStatus.disponible
        ? (isLocation ? PropertyStatus.occupee : PropertyStatus.vendue)
        : PropertyStatus.disponible;
    setState(() => _togglingStatus = true);
    try {
      await markPropertyStatus(
        ref,
        propertyId: widget.property.id,
        status: nextStatus,
      );
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _togglingStatus = false);
    }
  }

  /// "Valider" — fait passer la réservation à "accomplie" (fin de
  /// location/vente réalisée). N'existe que sur une réservation "en cours"
  /// (voir _ActionRow, où cette rangée n'est construite que pour ce statut),
  /// donc jamais visible sur une réservation déjà annulée ou accomplie.
  Future<void> _complete() async {
    setState(() => _completingReservation = true);
    try {
      await completeReservation(ref, widget.reservation.id);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _completingReservation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _OwnerActionButton(
              label: 'Discuter',
              isLoading: _openingChat,
              onTap: _openingChat ? null : _openChat,
              color: AppColors.primary,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _OwnerActionButton(
              label: switch (widget.property.status) {
                PropertyStatus.disponible =>
                  widget.property.transactionType == TransactionType.location
                      ? 'Marquer occupé'
                      : 'Marquer vendu',
                PropertyStatus.occupee ||
                PropertyStatus.vendue ||
                PropertyStatus.accomplie ||
                PropertyStatus.annulee => 'Marquer disponible',
              },
              isLoading: _togglingStatus,
              onTap: _togglingStatus ? null : _toggleOccupied,
              color: AppColors.textPrimary,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _OwnerActionButton(
              label: 'Valider',
              isLoading: _completingReservation,
              onTap: _completingReservation ? null : _complete,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton d'action propriétaire (Discuter / Marquer occupé-disponible /
/// Valider) : FittedBox pour ne jamais tronquer "Marquer disponible" (le
/// plus long des trois libellés) maintenant que la rangée passe de 2 à 3
/// colonnes — même principe que la barre de navigation basse
/// (main_bottom_nav.dart), jamais un `overflow: ellipsis`.
class _OwnerActionButton extends StatelessWidget {
  const _OwnerActionButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
        ),
      ),
    );
  }
}
