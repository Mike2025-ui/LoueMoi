import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Bouton pilule/arrondi utilisé pour Location/Vente, Type de bien et
/// catégories de logement dans les filtres.
class FilterToggleChip extends StatelessWidget {
  const FilterToggleChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.expanded = true,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final chip = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
    return expanded ? Expanded(child: chip) : chip;
  }
}
