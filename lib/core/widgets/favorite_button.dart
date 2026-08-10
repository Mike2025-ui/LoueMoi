import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'circular_icon_button.dart';

/// Bouton coeur : contour (OFF) / rouge plein (ON). Purement présentationnel,
/// l'état persistant est géré par le provider appelant.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
  });

  final bool isFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CircularIconButton(
      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
      iconColor: isFavorite ? AppColors.favoriteActive : AppColors.favoriteInactive,
      onTap: onTap,
    );
  }
}
