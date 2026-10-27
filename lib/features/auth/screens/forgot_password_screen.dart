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

/// "Mot de passe oublié" étape 1 : Numéro de téléphone → OTP SMS.
/// Architecture prête, aucun fournisseur SMS réel branché (voir
/// accounts/sms.py côté Django) — le flux est fonctionnel de bout en bout,
/// seul l'envoi effectif du SMS est un bouchon de développement.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.replaceAll(RegExp(r'\s+'), '').trim();
    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.requestPasswordReset(phone);
      if (!mounted) return;
      context.push(AppRoutes.resetPasswordPath(phone));
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
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saisissez votre numéro de téléphone. Si un compte y est associé, '
                  'un code de vérification vous sera envoyé par SMS.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Numéro Tel',
                  hint: '',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Envoyer le code',
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
