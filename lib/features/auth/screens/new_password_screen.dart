import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// "Mot de passe oublié" étape 3 : Saisie du nouveau mot de passe.
/// Accessible UNIQUEMENT après validation préalable du code OTP alphanumérique.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({
    super.key,
    required this.phone,
    required this.code,
  });

  final String phone;
  final String code;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final cleanPhone = widget.phone.replaceAll(RegExp(r'\s+'), '').trim();
      final cleanCode = widget.code.trim();

      await repository.confirmPasswordReset(
        phone: cleanPhone,
        code: cleanCode,
        newPassword: _passwordController.text,
      );

      if (!mounted) return;
      TextInput.finishAutofillContext();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe réinitialisé. Vous pouvez vous connecter.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('${AppRoutes.login}?phone=${Uri.encodeComponent(cleanPhone)}');
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nouveau mot de passe')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre identité a été vérifiée avec succès. Veuillez définir votre nouveau mot de passe.',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Nouveau mot de passe',
                    hint: 'Au moins 6 caractères',
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
                    keyboardType: TextInputType.visiblePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Confirmer le mot de passe',
                    hint: 'Répétez votre mot de passe',
                    controller: _confirmPasswordController,
                    focusNode: _confirmPasswordFocusNode,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    keyboardType: TextInputType.visiblePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    validator: (v) => Validators.confirmPassword(v, _passwordController.text),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Enregistrer le mot de passe',
                    isLoading: _isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
