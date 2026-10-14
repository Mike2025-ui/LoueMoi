import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import 'primary_button.dart';

/// Barre d'action fixe en bas de l'écran de détail : prix + bouton Reserver,
/// ou un message ("Propriété occupée"/"Propriété vendue"...) quand la
/// propriété n'est plus disponible — le message exact dépend de la raison
/// (occupee vs vendue), jamais codé en dur ici.
class BottomReservationBar extends StatelessWidget {
  const BottomReservationBar({
    super.key,
    required this.price,
    required this.priceSuffix,
    required this.isAvailable,
    required this.onReserve,
    this.unavailableLabel = 'Propriété occupée',
  });

  final double price;
  final String priceSuffix;
  final bool isAvailable;
  final VoidCallback onReserve;
  final String unavailableLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: AppShadows.bottomBar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.md,
          ),
          child: isAvailable
              ? Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.price,
                          children: [
                            TextSpan(text: Formatters.price(price)),
                            TextSpan(
                              text: ' $priceSuffix',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: PrimaryButton(label: 'Reserver', onPressed: onReserve),
                    ),
                  ],
                )
              : Center(
                  child: Text(
                    unavailableLabel,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
