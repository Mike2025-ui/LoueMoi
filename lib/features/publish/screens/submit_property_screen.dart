import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Écran dédié aux propriétaires désirant confier leur bien à LoueMoi
/// pour le faire visiter et louer sans aucun frais d'agence.
class SubmitPropertyScreen extends StatelessWidget {
  const SubmitPropertyScreen({super.key});

  Future<void> _openWhatsAppSupport(BuildContext context) async {
    final cleanPhone = Env.supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    const message =
        'Bonjour LoueMoi, je suis propriétaire et je souhaite vous confier un bien immobilier pour mise en location / vente.';
    final appUri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'ouvrir WhatsApp sur cet appareil."),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _callSupport(BuildContext context) async {
    final cleanPhone = Env.supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'effectuer l'appel."),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Confier un bien'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.real_estate_agent_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Vous souhaitez proposer un bien immobilier ?',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'LoueMoi centralise et assure la promotion de vos biens, organise les visites physiques sur le terrain et trouve vos locataires rapidement.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: const [
                    _PerkRow(
                      icon: Icons.check_circle_outline,
                      title: 'Zéro commission d’agence',
                      subtitle:
                          'Aucun mois d’agence prélevé, une transparence totale pour vous et vos locataires.',
                    ),
                    SizedBox(height: AppSpacing.md),
                    _PerkRow(
                      icon: Icons.groups_outlined,
                      title: 'Visites physiques prises en charge',
                      subtitle:
                          'Nos agents de terrain accueillent et font visiter les logements aux candidats qualifiés.',
                    ),
                    SizedBox(height: AppSpacing.md),
                    _PerkRow(
                      icon: Icons.photo_camera_outlined,
                      title: 'Publication et mise en avant',
                      subtitle:
                          'Photos de qualité, vérification des informations et visibilité maximale sur toute l’application.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: () => _openWhatsAppSupport(context),
                icon: const Icon(Icons.chat, color: AppColors.white, size: 20),
                label: const Text(
                  'Nous contacter sur WhatsApp',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _callSupport(context),
                icon: const Icon(Icons.phone, size: 20, color: AppColors.primary),
                label: Text(
                  'Appeler le standard',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

