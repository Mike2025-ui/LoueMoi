import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Badge de statut pilule (Location / Vente / Occupée / Studio / Villa...).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.fontSize = 13,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  factory StatusBadge.location() => const StatusBadge(
        label: 'Location',
        backgroundColor: AppColors.statusLocationBg,
        textColor: AppColors.statusLocationText,
      );

  factory StatusBadge.vente() => const StatusBadge(
        label: 'Vente',
        backgroundColor: AppColors.statusVenteBg,
        textColor: AppColors.statusVenteText,
      );

  factory StatusBadge.occupee() => const StatusBadge(
        label: 'Occupée',
        backgroundColor: AppColors.statusOccupeeBg,
        textColor: AppColors.statusOccupeeText,
      );

  /// Même palette que .occupee() : les deux signifient "plus disponible",
  /// juste pour des transactions différentes (location vs vente) — pas
  /// besoin d'une troisième couleur pour la même sémantique visuelle.
  factory StatusBadge.vendue() => const StatusBadge(
        label: 'Vendue',
        backgroundColor: AppColors.statusOccupeeBg,
        textColor: AppColors.statusOccupeeText,
      );

  factory StatusBadge.category(String label) => StatusBadge(
        label: label,
        backgroundColor: AppColors.primaryLight,
        textColor: AppColors.primary,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
