import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ReservationConfirmationScreen extends StatefulWidget {
  const ReservationConfirmationScreen({super.key});

  @override
  State<ReservationConfirmationScreen> createState() =>
      _ReservationConfirmationScreenState();
}

class _ReservationConfirmationScreenState
    extends State<ReservationConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) context.pushReplacement(AppRoutes.reservationCongrats);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 72),
            SizedBox(height: AppSpacing.md),
            Text(
              'Réservation enregistrée !',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
