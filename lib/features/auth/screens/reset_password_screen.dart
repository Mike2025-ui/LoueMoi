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
  final _codeFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _countdownNotifier = ValueNotifier<int>(60);
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Timer? _timer;

  String get _normalizedPhone {
    String p = widget.phone.trim();
    if (p.startsWith('225') && !p.startsWith('+')) {
      p = '+$p';
    }
    return p;
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownNotifier.dispose();
    _codeFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
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
      if (_countdownNotifier.value <= 1) {
        timer.cancel();
        _countdownNotifier.value = 0;
      } else {
        _countdownNotifier.value--;
      }
    });
  }

  void _startCountdown([int seconds = 62]) {
    _timer?.cancel();
    _countdownNotifier.value = seconds;
    _startTimer();
  }

  Future<void> _resendCode() async {
    if (_countdownNotifier.value > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final cleanPhone = _normalizedPhone.replaceAll(RegExp(r'\s+'), '').trim();
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
        _startCountdown(62);
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
      final cleanPhone = _normalizedPhone.replaceAll(RegExp(r'\s+'), '').trim();
      final cleanCode = _codeController.text.replaceAll(RegExp(r'\D'), '').trim();
      await repository.confirmPasswordReset(
        phone: cleanPhone,
        code: cleanCode.isNotEmpty ? cleanCode : _codeController.text.trim(),
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
        _codeController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _codeController.text.length,
        );
        _codeFocusNode.requestFocus();
      }
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
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrez le code reçu par SMS au $_normalizedPhone et votre nouveau mot de passe.',
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
                    focusNode: _codeFocusNode,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
                        final truncated = digits.length > 6 ? digits.substring(0, 6) : digits;
                        return TextEditingValue(
                          text: truncated,
                          selection: TextSelection.collapsed(offset: truncated.length),
                        );
                      }),
                    ],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Le code OTP est requis';
                      }
                      final digits = v.trim().replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 6) {
                        return 'Le code doit contenir exactement 6 chiffres';
                      }
                      return null;
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _countdownNotifier,
                      builder: (context, countdown, _) {
                        return TextButton(
                          onPressed: (countdown > 0 || _isResending) ? null : _resendCode,
                          child: Text(
                            _isResending
                                ? 'Envoi en cours...'
                                : countdown > 0
                                    ? 'Renvoyer dans ${countdown}s'
                                    : 'Renvoyer le code SMS',
                            style: TextStyle(
                              color: countdown > 0 ? AppColors.textSecondary : AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
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
                  label: 'Réinitialiser',
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
