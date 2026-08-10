import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/providers/auth_providers.dart';
import '../widgets/profile_menu_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              const Text('Profil', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.lg),
              CircleAvatar(
                radius: AppSizes.avatarLg / 2,
                backgroundColor: AppColors.primary,
                backgroundImage: user?.photo != null
                    ? NetworkImage(buildMediaUrl(user!.photo!))
                    : null,
                child: user?.photo == null
                    ? const Icon(Icons.person, size: 48, color: AppColors.white)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(user?.fullName ?? 'Utilisateur', style: AppTextStyles.h3),
              const SizedBox(height: 2),
              Text(user?.phone ?? '', style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xl),
              ProfileMenuTile(
                icon: Icons.chat_bubble_outline,
                label: 'Messages',
                onTap: () => context.push(AppRoutes.messages),
              ),
              ProfileMenuTile(
                icon: Icons.receipt_long_outlined,
                label: 'Propriétés contactés',
                onTap: () => showComingSoonSnackbar(context, 'Propriétés contactés'),
              ),
              ProfileMenuTile(
                icon: Icons.person_add_alt_outlined,
                label: 'Informations personnelles',
                onTap: () => showComingSoonSnackbar(context, 'Informations personnelles'),
              ),
              if (user?.isAgent ?? false)
                ProfileMenuTile(
                  icon: Icons.groups_outlined,
                  label: 'Mon espace agent',
                  onTap: () => context.push(AppRoutes.agentSpace),
                ),
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: () => ref.read(authControllerProvider.notifier).logout().then(
                      (_) {
                        if (context.mounted) context.go(AppRoutes.login);
                      },
                    ),
                child: const Text(
                  'Deconnexion',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
