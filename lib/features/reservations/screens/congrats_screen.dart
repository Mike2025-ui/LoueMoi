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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFDCFCE7),
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.success, width: 3),
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Demande enregistrée !',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Votre demande de visite a bien été transmise à l’équipe LoueMoi.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  children: const [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.phone_in_talk_outlined, color: Color(0xFF16A34A), size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Un conseiller LoueMoi vous contactera par appel ou WhatsApp pour planifier l’heure de votre visite physique.',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Divider(color: Color(0xFFBBF7D0)),
                    SizedBox(height: AppSpacing.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_outlined, color: Color(0xFF16A34A), size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Visite 100% gratuite et directe : zéro frais de visite et zéro commission d’agence.',
                            style: TextStyle(
                              color: Color(0xFF166534),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              PrimaryButton(
                label: 'Voir mes réservations',
                onPressed: () => context.go(AppRoutes.reservationsList),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text(
                  'Retour à l’accueil',
                  style: AppTextStyles.link,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
