import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/agent_providers.dart';

/// "Modification du profil" — champs autorisés uniquement : le téléphone
/// (identifiant de connexion) et le rôle ne sont jamais modifiables ici, le
/// rôle reste contrôlé côté Django (read_only_fields = ["id", "role"] sur
/// UserSerializer). Pour un agent, les champs AgentProfile (agence,
/// whatsapp pro, description) sont modifiables séparément — jamais
/// is_verified/rating, qui restent en lecture seule côté serializer même en
/// cas de tentative de triche depuis ce formulaire.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _agencyNameController;
  late final TextEditingController _agentWhatsappController;
  late final TextEditingController _descriptionController;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    final agentProfile = user?.agentProfile;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _whatsappController = TextEditingController(text: user?.whatsapp ?? '');
    _agencyNameController = TextEditingController(text: agentProfile?.agencyName ?? '');
    _agentWhatsappController = TextEditingController(text: agentProfile?.whatsapp ?? '');
    _descriptionController = TextEditingController(text: agentProfile?.description ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _whatsappController.dispose();
    _agencyNameController.dispose();
    _agentWhatsappController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final authController = ref.read(authControllerProvider.notifier);
      await authController.updateProfile({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
      });

      final isAgent = ref.read(authControllerProvider).valueOrNull?.isAgent ?? false;
      if (isAgent) {
        final updatedProfile = await ref.read(agentProfileRepositoryProvider).updateAgentProfile({
          'agency_name': _agencyNameController.text.trim(),
          'whatsapp': _agentWhatsappController.text.trim(),
          'description': _descriptionController.text.trim(),
        });
        authController.applyUpdatedAgentProfile(updatedProfile);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil mis à jour avec succès.')));
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isAgent = user?.isAgent ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _uploadingPhoto ? null : () => _showPhotoOptions(context, user?.photo != null),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: AppSizes.avatarLg / 2,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: user?.photo != null
                                ? NetworkImage(buildMediaUrl(user!.photo!))
                                : null,
                            onBackgroundImageError: user?.photo != null ? (_, __) {} : null,
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
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: _uploadingPhoto ? null : () => _showPhotoOptions(context, user?.photo != null),
                        child: Text(
                          user?.photo != null ? 'Modifier la photo' : 'Ajouter une photo de profil',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Prénom',
                controller: _firstNameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Nom',
                controller: _lastNameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis.' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'WhatsApp',
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
              ),
              if (isAgent) ...[
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.md),
                const Text('Profil professionnel', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Agence', controller: _agencyNameController),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'WhatsApp professionnel',
                  controller: _agentWhatsappController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Description',
                  controller: _descriptionController,
                  maxLines: 4,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Enregistrer',
                isLoading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
