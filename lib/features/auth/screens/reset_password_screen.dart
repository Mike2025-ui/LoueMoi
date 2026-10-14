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
import '../providers/auth_providers.dart';

/// "Mot de passe oublié" étape 2 : Vérification OTP + Nouveau mot de passe,
/// sur un seul écran (une seule requête POST /api/auth/password-reset/
/// confirm/ côté Django, qui valide le code et change le mot de passe en
/// une transaction). En cas de succès, retour à Connexion.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.confirmPasswordReset(
        phone: widget.phone,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe réinitialisé. Vous pouvez vous connecter.')),
      );
      context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vérification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrez le code reçu par SMS au ${widget.phone} et votre nouveau mot de passe.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Code de vérification',
                  hint: '',
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  validator: (v) => Validators.required(v, message: 'Le code est requis'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Nouveau mot de passe',
                  hint: '',
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Confirmer le mot de passe',
                  hint: '',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  validator: (v) =>
                      Validators.confirmPassword(v, _passwordController.text),
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Réinitialiser',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
