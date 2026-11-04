import 'dart:async';
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
  bool _isResending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _countdownSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds <= 1) {
        timer.cancel();
        setState(() => _countdownSeconds = 0);
      } else {
        setState(() => _countdownSeconds--);
      }
    });
  }

  void _startCountdown([int seconds = 60]) {
    _timer?.cancel();
    if (mounted) {
      setState(() => _countdownSeconds = seconds);
    } else {
      _countdownSeconds = seconds;
    }
    _startTimer();
  }

  Future<void> _resendCode() async {
    if (_countdownSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final cleanPhone = widget.phone.replaceAll(RegExp(r'\s+'), '').trim();
      final result = await repository.requestPasswordReset(cleanPhone);
      if (!mounted) return;

      if (result['cooldown'] == true) {
        final waitSec = (result['retry_after'] as num?)?.toInt() ?? 60;
        _startCountdown(waitSec);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veuillez patienter encore ${waitSec}s avant de redemander un code.'),
            backgroundColor: AppColors.warning,
          ),
        );
      } else {
        _startCountdown(60);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Un nouveau code de vérification a été envoyé par SMS.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final cleanPhone = widget.phone.replaceAll(RegExp(r'\s+'), '').trim();
      final cleanCode = _codeController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim();
      await repository.confirmPasswordReset(
        phone: cleanPhone,
        code: cleanCode.isNotEmpty ? cleanCode : _codeController.text.trim(),
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
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Le code reçu est valable pendant 10 minutes.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Code de vérification OTP',
                  hint: '6 chiffres (ex: 123456)',
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Le code OTP est requis';
                    }
                    if (v.trim().length != 6) {
                      return 'Le code doit contenir exactement 6 chiffres';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: (_countdownSeconds > 0 || _isResending) ? null : _resendCode,
                    child: Text(
                      _isResending
                          ? 'Envoi en cours...'
                          : _countdownSeconds > 0
                              ? 'Renvoyer dans ${_countdownSeconds}s'
                              : 'Renvoyer le code SMS',
                      style: TextStyle(
                        color: _countdownSeconds > 0 ? AppColors.textSecondary : AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Nouveau mot de passe',
                  hint: 'Au moins 6 caractères',
                  controller: _passwordController,
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
