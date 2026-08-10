import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

class CongratsScreen extends StatelessWidget {
  const CongratsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: AppColors.success, width: 3)),
                ),
                child: const Icon(Icons.check, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Félicitation !', style: AppTextStyles.h2),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Nous vous remercions d’avoir utiliser l’application',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const Spacer(flex: 4),
              PrimaryButton(
                label: 'Retour au menu',
                onPressed: () => context.go(AppRoutes.home),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
