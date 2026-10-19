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
import '../../properties/models/property.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';

/// GET /api/agent/properties/ — uniquement les annonces de l'agent
/// connecté, filtrées côté Django (jamais recalculé côté Flutter). Affiche
/// statut/vues/favoris réels + actions Modifier/Supprimer (203/403 côté
/// Django si l'annonce n'appartient pas à l'agent connecté).
class MyPropertiesScreen extends ConsumerWidget {
  const MyPropertiesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Supprimer cette annonce ?'),
        content: Text(
          '« ${property.title} » sera définitivement supprimée.\n\n'
          'Note : Une annonce avec une réservation en cours ne peut pas être supprimée. La réservation doit d\'abord être accomplie ou annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repository = ref.read(propertyRepositoryProvider);
      await repository.deleteProperty(property.id);
      ref.invalidate(myPropertiesProvider);
      ref.invalidate(propertiesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Annonce supprimée.')));
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  /// CORRECTION MÉTIER : une réservation ne rend plus une annonce "occupee"
  /// automatiquement (voir ReservationViewSet.perform_create côté Django) —
  /// c'est désormais au propriétaire de décider explicitement ici. Passe par
  /// markPropertyStatus (l'action dédiée /status/), jamais le PATCH
  /// générique : `status` y est désormais en lecture seule côté Django
  /// (voir PropertySerializer.read_only_fields) précisément pour empêcher
  /// de contourner la validation occupee/vendue cohérente avec
  /// transaction_type — "occupee" n'a de sens qu'en location, "vendue"
  /// qu'en vente, jamais l'inverse.
  Future<void> _toggleStatus(BuildContext context, WidgetRef ref, Property property) async {
    if (property.status == PropertyStatus.accomplie || property.status == PropertyStatus.annulee) {
      return;
    }
    final isLocation = property.transactionType == TransactionType.location;
    final newStatus = property.status == PropertyStatus.disponible
        ? (isLocation ? PropertyStatus.occupee : PropertyStatus.vendue)
        : PropertyStatus.disponible;
    try {
      await markPropertyStatus(ref, propertyId: property.id, status: newStatus);
      ref.invalidate(myPropertiesProvider);
      ref.invalidate(propertiesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Annonce marquée ${newStatus.label.toLowerCase()}.')),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  /// "Reconduire un bien" : réservé aux annonces annulées ou expirées (30 jours).
  Future<void> _renew(BuildContext context, WidgetRef ref, Property property) async {
    if (property.status != PropertyStatus.annulee && !property.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seules les annonces annulées ou expirées peuvent être reconduites.')),
      );
      return;
    }
    try {
      final repository = ref.read(propertyRepositoryProvider);
      await repository.renewProperty(property.id);
      await markPropertyStatus(ref, propertyId: property.id, status: PropertyStatus.disponible);
      ref.invalidate(myPropertiesProvider);
      ref.invalidate(propertiesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Annonce reconduite avec succès.')));
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  /// Permet à l'agent ou au bailleur d'annuler une annonce pour pouvoir la reconduire ultérieurement.
  Future<void> _cancelProperty(BuildContext context, WidgetRef ref, Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Annuler cette annonce ?'),
        content: Text('« ${property.title} » sera marquée comme annulée. Vous pourrez la reconduire à tout moment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annuler l\'annonce', style: TextStyle(color: AppColors.warning)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await markPropertyStatus(ref, propertyId: property.id, status: PropertyStatus.annulee);
      ref.invalidate(myPropertiesProvider);
      ref.invalidate(propertiesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce annulée. Vous pouvez la reconduire quand vous le souhaitez.')),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(myPropertiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mes annonces')),
      body: propertiesAsync.when(
        data: (properties) {
          if (properties.isEmpty) {
            return const Center(
              child: Text('Vous n’avez publié aucune annonce.', style: AppTextStyles.caption),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myPropertiesProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: properties.length,
              separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final property = properties[index];
                return _MyPropertyTile(
                  property: property,
                  onTap: () => context.push(AppRoutes.propertyDetailPath(property.id)),
                  onEdit: () => context.push(AppRoutes.editPropertyPath(property.id)),
                  onDelete: () => _confirmDelete(context, ref, property),
                  onToggleStatus: () => _toggleStatus(context, ref, property),
                  onRenew: () => _renew(context, ref, property),
                  onCancel: () => _cancelProperty(context, ref, property),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger vos annonces.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}

class _MyPropertyTile extends StatelessWidget {
  const _MyPropertyTile({
    required this.property,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    required this.onRenew,
    required this.onCancel,
  });

  final Property property;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final VoidCallback onRenew;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: PropertyImage(property.coverImage, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title,
                        style: AppTextStyles.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(Formatters.price(property.price), style: AppTextStyles.priceSm),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 13, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              property.locationLabel,
                              style: AppTextStyles.small,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 4,
                        children: [
                          InkWell(
                            onTap: onToggleStatus,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: switch (property.status) {
                              PropertyStatus.occupee => StatusBadge.occupee(),
                              PropertyStatus.vendue => StatusBadge.vendue(),
                              PropertyStatus.accomplie => StatusBadge.accomplie(),
                              PropertyStatus.annulee => StatusBadge.annulee(),
                              PropertyStatus.disponible => const StatusBadge(
                                  label: 'Disponible',
                                  backgroundColor: AppColors.statusLocationBg,
                                  textColor: AppColors.statusLocationText,
                                  fontSize: 11,
                                ),
                            },
                          ),
                          StatusBadge.category(property.category),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            // Colonne plutôt qu'une seule Row surchargée : sur un écran
            // étroit ou avec une date longue, tasser stats + 3 boutons sur
            // une seule ligne non contrainte provoquait un débordement
            // horizontal (RenderFlex overflow). Le Wrap ci-dessous laisse
            // les actions passer à la ligne proprement si nécessaire.
            Row(
              children: [
                const Icon(Icons.visibility_outlined, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('${property.viewsCount}', style: AppTextStyles.small),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.favorite_outline, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('${property.favoritesCount}', style: AppTextStyles.small),
                const SizedBox(width: AppSpacing.md),
                const Icon(Icons.event_outlined, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    Formatters.shortDate(property.createdAt),
                    style: AppTextStyles.small,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (property.status == PropertyStatus.annulee || property.isExpired)
                  TextButton.icon(
                    onPressed: onRenew,
                    icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
                    label: const Text('Reconduire', style: AppTextStyles.link),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else if (property.status != PropertyStatus.accomplie)
                  TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.warning),
                    label: const Text('Annuler', style: TextStyle(color: AppColors.warning, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (property.status != PropertyStatus.accomplie)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                    label: const Text('Modifier', style: AppTextStyles.link),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                  label: const Text('Supprimer', style: TextStyle(color: AppColors.danger, fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
