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
import '../providers/contacted_properties_provider.dart';

/// Annonces au sujet desquelles l'utilisateur a réellement ouvert une
/// conversation (voir contacted_properties_provider.dart) — jamais de
/// données inventées : liste vide si aucune conversation n'est liée à une
/// annonce précise.
class ContactedPropertiesScreen extends ConsumerWidget {
  const ContactedPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(contactedPropertiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Propriétés contactées')),
      body: propertiesAsync.when(
        data: (properties) {
          if (properties.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.screenPadding),
                child: Text(
                  "Vous n'avez encore contacté aucune annonce.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
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
                    ref.invalidate(contactedPropertiesProvider);
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
          child: Text('Impossible de charger vos propriétés contactées.',
              style: AppTextStyles.caption),
        ),
      ),
    );
  }
}
