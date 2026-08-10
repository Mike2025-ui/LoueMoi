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
        content: Text('« ${property.title} » sera définitivement supprimée.'),
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
  });

  final Property property;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                          property.status == PropertyStatus.occupee
                              ? StatusBadge.occupee()
                              : const StatusBadge(
                                  label: 'Disponible',
                                  backgroundColor: AppColors.statusLocationBg,
                                  textColor: AppColors.statusLocationText,
                                  fontSize: 11,
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
                Text(Formatters.shortDate(property.createdAt), style: AppTextStyles.small),
                const Spacer(),
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
