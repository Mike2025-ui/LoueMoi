import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_logo.dart';

/// Page de maintenance complète pour la version Web de LoueMoi.
/// Affichée pour tous les visiteurs du site web, elle explique que la version web
/// est en cours de maintenance et invite à utiliser l'application mobile Android (APK).
class WebMaintenanceScreen extends StatelessWidget {
  const WebMaintenanceScreen({super.key});

  Future<void> _downloadApk(BuildContext context) async {
    final apkUrl = Uri.parse('${Env.apiBaseUrl}/LoueMoi-release.apk');
    try {
      if (await canLaunchUrl(apkUrl)) {
        await launchUrl(apkUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(apkUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le téléchargement de l’APK a été lancé.')),
        );
      }
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    final supportPhone = '+2250700000000';
    final message = 'Bonjour LoueMoi, je vous contacte depuis le site web en maintenance.';
    final webUri = Uri.parse('https://wa.me/$supportPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Logo LoueMoi officiel
                  const AppLogo(iconSize: 56),
                  const SizedBox(height: 24),

                  // 2. Carte principale de Maintenance
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        // Illustration visuelle : Ordinateur, Tablette et Clé à molette
                        Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.construction_rounded,
                                  size: 50,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'SITE EN MAINTENANCE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        const Text(
                          'Plateforme Web en cours de maintenance',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          'Nous effectuons actuellement une mise à jour technique majeure de notre version web afin d’optimiser vos recherches immobilières. Nous serons de retour très bientôt.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 20),

                        // Section Application Mobile
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'L’application mobile est 100% opérationnelle',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Recherchez, visitez, réservez ou publiez vos logements directement depuis notre application Android.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF166534),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Bouton Télécharger l'APK ultra attractif
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _downloadApk(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0F766E),
                                    Color(0xFF009688),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF009688).withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.android_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'APPLICATION SMARTPHONE',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Télécharger l’App Android (APK)',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.download_rounded,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Support et assistance
                  InkWell(
                    onTap: () => _contactSupport(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.headset_mic_outlined, size: 18, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Text(
                            'Une question ? Contacter l’équipe LoueMoi',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. Copyright
                  const Text(
                    '© 2026 LoueMoi. Tous droits réservés.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
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

