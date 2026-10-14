import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/auth_providers.dart';

String _roleLabel(UserRole? role) => switch (role) {
      UserRole.agent => 'Agent immobilier',
      UserRole.bailleur => 'Bailleur',
      UserRole.client || null => 'Client',
    };

/// "Informations personnelles" — lecture seule, données réellement
/// renvoyées par GET /api/users/me/ (via authControllerProvider, déjà
/// chargé à la connexion). Réutilise AppTextField (enabled: false) plutôt
/// qu'un nouveau composant d'affichage.
class PersonalInfoScreen extends ConsumerWidget {
  const PersonalInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Informations personnelles')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Prénom',
              controller: TextEditingController(text: user?.firstName ?? ''),
              enabled: false,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nom',
              controller: TextEditingController(text: user?.lastName ?? ''),
              enabled: false,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Téléphone',
              controller: TextEditingController(text: user?.phone ?? ''),
              enabled: false,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'WhatsApp',
              controller: TextEditingController(text: user?.whatsapp ?? ''),
              enabled: false,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Rôle',
              controller: TextEditingController(text: _roleLabel(user?.role)),
              enabled: false,
            ),
            if (user?.agentProfile != null) ...[
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              const Text('Profil professionnel', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Agence',
                controller: TextEditingController(text: user!.agentProfile!.agencyName),
                enabled: false,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Description',
                controller: TextEditingController(text: user.agentProfile!.description),
                enabled: false,
                maxLines: 3,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Modifier le profil',
              onPressed: () => context.push(AppRoutes.editProfile),
            ),
          ],
        ),
      ),
    );
  }
}
