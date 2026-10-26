import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/providers/auth_providers.dart';
import '../../payments/widgets/subscription_modal.dart';
import '../widgets/profile_menu_tile.dart';

/// Flux "Supprimer mon compte" (décision métier : désactivation, jamais de
/// suppression physique — voir AuthController.deactivateAccount) :
/// confirmation explicite, puis authentification supplémentaire par mot de
/// passe avant toute action, jamais un simple bouton qui agit directement.
Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Text('Supprimer mon compte ?'),
      content: const Text(
        'Votre compte sera désactivé et vous serez déconnecté. Vos annonces, réservations, '
        'messages et avis restent conservés — contactez-nous si vous souhaitez leur suppression '
        'définitive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Continuer',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final passwordController = TextEditingController();
  var isSubmitting = false;
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (statefulContext, setDialogState) {
        Future<void> submit() async {
          final password = passwordController.text;
          if (password.isEmpty) {
            setDialogState(() => errorText = 'Mot de passe requis.');
            return;
          }
          setDialogState(() {
            isSubmitting = true;
            errorText = null;
          });
          try {
            await ref
                .read(authControllerProvider.notifier)
                .deactivateAccount(password);
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            if (context.mounted) context.go(AppRoutes.login);
          } catch (e) {
            setDialogState(() {
              isSubmitting = false;
              errorText = 'Mot de passe incorrect.';
            });
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text('Confirmez votre mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Mot de passe',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => isSubmitting ? null : submit(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: isSubmitting ? null : submit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Supprimer mon compte',
                      style: TextStyle(color: AppColors.danger),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authControllerProvider.notifier).refreshProfile();
    });
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);
      await ref.read(authControllerProvider.notifier).uploadProfilePhoto(picked);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo de profil mise à jour avec succès.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto() async {
    try {
      setState(() => _uploadingPhoto = true);
      await ref.read(authControllerProvider.notifier).deleteProfilePhoto();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo de profil supprimée.'),
          backgroundColor: AppColors.textPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _contactSupport() async {
    const message = 'Bonjour LoueMoi, je souhaite obtenir des informations concernant mon compte.';
    final cleanPhone = Env.supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showPhotoOptions(BuildContext context, bool hasPhoto) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Text(
                  'Photo de profil',
                  style: AppTextStyles.h3,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choisir dans la galerie'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: const Text('Supprimer la photo', style: TextStyle(color: AppColors.danger)),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _deletePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isVerified = user?.isVerifiedUser ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              const Text('Profil', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.lg),
              GestureDetector(
                onTap: _uploadingPhoto ? null : () => _showPhotoOptions(context, user?.photo != null),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: AppSizes.avatarLg / 2,
                      backgroundColor: AppColors.primaryLight,
                      backgroundImage: user?.photo != null
                          ? NetworkImage(buildMediaUrl(user!.photo!))
                          : null,
                      onBackgroundImageError: user?.photo != null ? (exception, stackTrace) {} : null,
                      child: _uploadingPhoto
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.primary,
                              ),
                            )
                          : (user?.photo == null
                              ? const Icon(
                                  Icons.person,
                                  size: 48,
                                  color: AppColors.primary,
                                )
                              : null),
                    ),
                    if (isVerified)
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user?.fullName ?? 'Utilisateur',
                    style: AppTextStyles.h3,
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(user?.phone ?? '', style: AppTextStyles.caption),
              if (isVerified) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: AppColors.primary, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Compte certifié',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              // Pas d'entrée "Messages" ici : la maquette n'en montre aucune
              // sur cet écran (l'onglet Messages de la bottom navigation
              // reste le seul accès aux conversations, inchangé).
              ProfileMenuTile(
                icon: Icons.receipt_long_outlined,
                label: 'Propriétés contactées',
                onTap: () => context.push(AppRoutes.contactedProperties),
              ),
              ProfileMenuTile(
                icon: Icons.person_add_alt_outlined,
                label: 'Informations personnelles',
                onTap: () => context.push(AppRoutes.personalInfo),
              ),
              ProfileMenuTile(
                icon: Icons.workspace_premium_outlined,
                label: (user?.hasActiveSubscription ?? false)
                    ? 'Mon forfait visites (Actif)'
                    : 'Forfait visites & mise en relation',
                onTap: () async {
                  await showSubscriptionModal(
                    context,
                    isPro: user?.canOwnProperties ?? false,
                    role: user?.role,
                  );
                  if (mounted) {
                    ref.read(authControllerProvider.notifier).refreshProfile();
                  }
                },
              ),
              if (user?.isAgent ?? false)
                ProfileMenuTile(
                  icon: Icons.groups_outlined,
                  label: 'Mon espace agent',
                  onTap: () => context.push(AppRoutes.agentSpace),
                ),
              if (user?.isBailleur ?? false)
                ProfileMenuTile(
                  icon: Icons.home_work_outlined,
                  label: 'Mon espace bailleur',
                  onTap: () => context.push(AppRoutes.bailleurSpace),
                ),
              ProfileMenuTile(
                icon: Icons.support_agent_outlined,
                label: 'Assistance WhatsApp (${Env.supportPhoneDisplay})',
                onTap: _contactSupport,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextButton(
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .logout()
                    .then((_) {
                      if (context.mounted) context.go(AppRoutes.login);
                    }),
                child: const Text(
                  'Deconnexion',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => _confirmDeleteAccount(context, ref),
                child: const Text(
                  'Supprimer mon compte',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
