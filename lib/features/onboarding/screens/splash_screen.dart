import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateWhenReady();
  }

  Future<void> _navigateWhenReady() async {
    final minSplashDelay = Future<void>.delayed(const Duration(milliseconds: 1400));
    final authReady = ref.read(authControllerProvider.notifier).ready;
    // Le splash reste visible au moins 1400ms (identité visuelle), et le
    // temps nécessaire à la restauration de session si elle est plus longue.
    await Future.wait([minSplashDelay, authReady]);
    if (!mounted) return;

    if (kIsWeb) {
      context.go(AppRoutes.maintenance);
      return;
    }

    final user = ref.read(authControllerProvider).valueOrNull;
    if (user != null) {
      if (user.needsActivation) {
        context.go(AppRoutes.pendingActivation);
      } else {
        context.go(AppRoutes.home);
      }
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AppLogo(iconSize: 48, textStyle: AppTextStyles.h1),
      ),
    );
  }
}
