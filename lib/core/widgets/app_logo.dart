import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Logo "LoueMoi" (icône immeuble + libellé), centralisé pour pouvoir changer
/// le nom de l'application facilement (voir [AppConstants.appDisplayName]).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.iconSize = 32,
    this.textStyle = AppTextStyles.logo,
  });

  final double iconSize;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.apartment_rounded, size: iconSize, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(AppConstants.appDisplayName, style: textStyle),
      ],
    );
  }
}
