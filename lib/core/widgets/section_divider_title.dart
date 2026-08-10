import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Titre de section avec traits + losanges de part et d'autre
/// (ex: "◆ Détails ◆" sur l'écran de détail propriété).
class SectionDividerTitle extends StatelessWidget {
  const SectionDividerTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.diamond, size: 8, color: AppColors.primary),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const Icon(Icons.diamond, size: 8, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

/// Simple titre de section (ex: "Type de bien" fond gris dans les filtres).
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}
