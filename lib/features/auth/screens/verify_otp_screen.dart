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
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';

/// "Mot de passe oublié" étape 2 : Vérification du code OTP alphanumérique.
/// L'utilisateur saisit son code reçu par SMS.
/// Une fois le code vérifié avec succès par le serveur, il est redirigé vers
/// l'écran dédié de saisie du nouveau mot de passe.
class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  final _countdownNotifier = ValueNotifier<int>(60);
  bool _isSubmitting = false;
  bool _isResending = false;
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
    _codeController.dispose();
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
      final cleanCode = _codeController.text.trim().toUpperCase();

      await repository.verifyPasswordResetOtp(
        phone: cleanPhone,
        code: cleanCode,
      );

      if (!mounted) return;
      TextInput.finishAutofillContext();

      context.push(
        AppRoutes.newPasswordPath(phone: cleanPhone, code: cleanCode),
      );
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
      appBar: AppBar(title: const Text('Vérification du code')),
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
                    'Entrez le code alphanumérique reçu par SMS au $_normalizedPhone.',
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
                    hint: '6 caractères alphanumériques (ex: 4K9B2X)',
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        final text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
                        final truncated = text.length > 6 ? text.substring(0, 6) : text;
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
                      final clean = v.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
                      if (clean.length != 6) {
                        return 'Le code doit contenir exactement 6 caractères alphanumériques';
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
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Vérifier le code',
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
