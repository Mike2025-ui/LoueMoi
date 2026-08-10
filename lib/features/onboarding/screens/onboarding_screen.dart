import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/primary_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 40,
                      width: MediaQuery.of(context).size.width * 0.42,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Image.asset(
                          AppAssets.onboarding1,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 40,
                      bottom: 0,
                      width: MediaQuery.of(context).size.width * 0.42,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Image.asset(
                          AppAssets.onboarding2,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const AppLogo(),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Trouve ta future maison adaptée\nà tes standards',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Une nouvelle manière de chercher, comparer et '
                'trouver le logement qui correspond à vos ambitions.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Continuer',
                onPressed: () => context.go(AppRoutes.login),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
