import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../models/user_role.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Client par défaut, conformément au cahier des charges.
  UserRole _selectedRole = UserRole.client;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomsController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final roleName = _selectedRole == UserRole.bailleur ? 'Bailleur' : 'Agent immobilier';
    final message = 'Bonjour LoueMoi, je souhaite faire activer mon compte $roleName.';
    final whatsappUrl = Uri.parse(
      'whatsapp://send?phone=+2250702065206&text=${Uri.encodeComponent(message)}',
    );
    final webUrl = Uri.parse(
      'https://wa.me/2250702065206?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir WhatsApp.")),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).register(
          firstName: _prenomsController.text.trim(),
          lastName: _nomController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
        );
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    state.when(
      data: (user) {
        if (user != null) context.go(AppRoutes.home);
      },
      loading: () {},
      error: (e, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const Text('Inscription', style: AppTextStyles.h1),
                const SizedBox(height: AppSpacing.lg),
                const Text('Type de compte', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _RoleOption(
                        label: 'Client',
                        isActive: _selectedRole == UserRole.client,
                        onTap: () => setState(() => _selectedRole = UserRole.client),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _RoleOption(
                        label: 'Bailleur',
                        isActive: _selectedRole == UserRole.bailleur,
                        onTap: () => setState(() => _selectedRole = UserRole.bailleur),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _RoleOption(
                        label: 'Agent',
                        isActive: _selectedRole == UserRole.agent,
                        onTap: () => setState(() => _selectedRole = UserRole.agent),
                      ),
                    ),
                  ],
                ),
                if (_selectedRole == UserRole.bailleur || _selectedRole == UserRole.agent) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_outlined, color: Color(0xFF15803D), size: 20),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Activation requise par l’administration',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Afin de garantir la sécurité, la fiabilité et l’authenticité des annonces sur LoueMoi, les comptes ${_selectedRole == UserRole.bailleur ? "Bailleur" : "Agent immobilier"} font l’objet d’une vérification et d’une validation par notre équipe avant toute publication.\n\nVous pouvez créer votre compte ci-dessous, puis nous contacter directement sur WhatsApp pour finaliser son activation.',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF166534),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _openWhatsApp,
                            icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                            label: const Text(
                              'Nous contacter sur WhatsApp',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Nom',
                  controller: _nomController,
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Prenoms',
                  controller: _prenomsController,
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Numéro tel & whatsapp',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Mot de passe',
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Confirmer mot de passe',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  validator: (v) =>
                      Validators.confirmPassword(v, _passwordController.text),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Inscription',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Connexion', style: AppTextStyles.link),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilule Client / Agent immobilier — même style que le toggle
/// Location/Vente de l'écran Menu (aucune nouvelle identité visuelle).
class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: AppSizes.buttonHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
