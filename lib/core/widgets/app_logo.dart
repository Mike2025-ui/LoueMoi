import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Logo "LoueMoi" (icône immeuble moderne en badge dégradé + libellé),
/// centralisé pour garantir l'identité visuelle de marque de LoueMoi dans toute l'application.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.iconSize = 32,
    this.textStyle = AppTextStyles.logo,
    this.useBadge = true,
    this.showText = true,
  });

  final double iconSize;
  final TextStyle textStyle;
  final bool useBadge;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget;
    if (useBadge) {
      final radius = iconSize * 0.28;
      iconWidget = Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C6EF0), Color(0xFF503CD7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.apartment_rounded,
            size: iconSize * 0.64,
            color: AppColors.white,
          ),
        ),
      );
    } else {
      iconWidget = Icon(
        Icons.apartment_rounded,
        size: iconSize,
        color: AppColors.primary,
      );
    }

    if (!showText) {
      return iconWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 10),
        Text(AppConstants.appDisplayName, style: textStyle),
      ],
    );
  }
}
