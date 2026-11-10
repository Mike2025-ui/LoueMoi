import 'package:flutter/material.dart';
import 'verify_otp_screen.dart';

export 'verify_otp_screen.dart';

/// Écran de vérification OTP (étape 2 du flux "Mot de passe oublié").
/// Rétro-compatible avec [VerifyOtpScreen].
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return VerifyOtpScreen(phone: phone);
  }
}
