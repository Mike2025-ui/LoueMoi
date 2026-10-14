import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';
import '../../properties/widgets/property_card.dart';

/// "Propriétés vendues" — menu Espace agent. Réutilise myPropertiesProvider
/// (déjà scopé côté serveur à l'agent/bailleur connecté, voir MyPropertiesView/
/// BailleurPropertiesView) et filtre côté Flutter sur transaction_type=vente
/// + status=vendue : jamais une deuxième architecture, jamais les biens
/// d'un autre agent ou d'un bailleur — le filtrage serveur de
/// myPropertiesProvider est déjà le seul rempart de permission nécessaire.
class SoldPropertiesScreen extends ConsumerWidget {
  const SoldPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(myPropertiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Propriétés vendues')),
      body: propertiesAsync.when(
        data: (properties) {
          final sold = properties
              .where((p) =>
                  p.transactionType == TransactionType.vente &&
                  p.status == PropertyStatus.vendue)
              .toList();
          if (sold.isEmpty) {
            return const Center(
              child: Text('Aucune propriété vendue pour le moment.', style: AppTextStyles.caption),
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
            itemCount: sold.length,
            itemBuilder: (context, index) {
              final property = sold[index];
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
          child: Text('Impossible de charger vos annonces.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}
