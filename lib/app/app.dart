import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/network/network_providers.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/providers/auth_providers.dart';
import 'router.dart';
import 'routes.dart';

class LoueMoiApp extends ConsumerWidget {
  const LoueMoiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Session expirée (401 + refresh KO) détectée par l'AuthInterceptor :
    // déconnexion locale immédiate et retour à l'écran de connexion.
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      ref.read(authControllerProvider.notifier).forceLogout();
      router.go(AppRoutes.login);
    });

    return MaterialApp.router(
      title: AppConstants.appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
