import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
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
    final isAgent = ref.watch(authControllerProvider).valueOrNull?.isAgent ?? false;

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
