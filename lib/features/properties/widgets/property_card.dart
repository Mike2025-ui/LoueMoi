import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/widgets/property_image.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/property.dart';

/// Carte annonce (grille 2 colonnes), utilisée sur Menu et Favoris.
class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Property property;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: PropertyImage(property.coverImage, fit: BoxFit.cover),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: _TimeChip(createdAt: property.createdAt),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: FavoriteButton(
                    isFavorite: property.isFavorite,
                    onTap: onFavoriteTap,
                  ),
                ),
                if (property.isOccupee)
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: StatusBadge.occupee(),
                  ),
                if (property.isVendue)
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: StatusBadge.vendue(),
                  ),
                if (property.isAnnulee)
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: StatusBadge.annulee(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(Formatters.price(property.price), style: AppTextStyles.priceSm),
          const SizedBox(height: 2),
          Text(property.category, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.primary),
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
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.overlayDark,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 12, color: AppColors.white),
          const SizedBox(width: 4),
          Text(
            Formatters.relativeTime(createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.white),
          ),
        ],
      ),
    );
  }
}
