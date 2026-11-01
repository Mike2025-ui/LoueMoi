import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
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
  final _whatsappController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Compte unique : tout le monde est client / utilisateur sur LoueMoi
  final UserRole _selectedRole = UserRole.client;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomsController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).register(
          firstName: _prenomsController.text.trim(),
          lastName: _nomController.text.trim(),
          phone: _phoneController.text.trim(),
          whatsapp: _whatsappController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
        );
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    state.when(
      data: (user) {
        if (user != null) {
          context.go(AppRoutes.home);
        }
      },
      loading: () {},
      error: (e, _) {
        showErrorSnackbar(context, e);
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
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Créez votre compte en quelques secondes pour planifier vos visites et échanger directement avec l’équipe LoueMoi.',
                  style: AppTextStyles.caption,
                ),
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
                  label: 'Numéro de téléphone',
                  hint: '+225 01 02 03 04 05',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Numéro WhatsApp (optionnel)',
                  hint: '+225 07 08 09 10 11',
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.optionalPhone,
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
