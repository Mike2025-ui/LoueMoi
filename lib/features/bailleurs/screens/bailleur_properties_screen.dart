import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../properties/providers/property_providers.dart';
import '../../properties/widgets/property_card.dart';

/// Annonces publiques d'un propriétaire donné — "voir ses annonces
/// publiques" du flux "Rechercher un propriétaire" (voir
/// BailleurSearchScreen). Ne montre que ce que `/api/properties/?agent=ID`
/// renvoie déjà publiquement : aucune donnée privée, aucun transfert de
/// propriété possible depuis cet écran.
class BailleurPropertiesScreen extends ConsumerWidget {
  const BailleurPropertiesScreen({super.key, required this.ownerId, required this.ownerName});

  final String ownerId;
  final String ownerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertiesByOwnerProvider(ownerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Annonces de $ownerName')),
      body: propertiesAsync.when(
        data: (properties) {
          if (properties.isEmpty) {
            return const Center(
              child: Text('Aucune annonce publique pour le moment.', style: AppTextStyles.caption),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              100,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.lg,
              childAspectRatio: 0.68,
            ),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              final property = properties[index];
              return PropertyCard(
                property: property,
                onTap: () => context.push(AppRoutes.propertyDetailPath(property.id)),
                onFavoriteTap: () async {
                  try {
                    await toggleFavorite(ref, property.id);
                  } catch (e) {
                    if (context.mounted) showErrorSnackbar(context, e);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger les annonces.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}
