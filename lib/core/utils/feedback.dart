import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Feedback utilisateur cohérent pour les actions pas encore branchées à un
/// vrai backend : chaque bouton doit réagir, même quand la fonctionnalité
/// complète arrive plus tard.
void showComingSoonSnackbar(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        margin: const EdgeInsets.all(AppSpacing.md),
        content: Text('$feature — bientôt disponible'),
      ),
    );
}

/// Affiche une erreur utilisateur (déjà en français, cf. [ApiException]).
void showErrorSnackbar(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        margin: const EdgeInsets.all(AppSpacing.md),
        content: Text(error.toString()),
      ),
    );
}
