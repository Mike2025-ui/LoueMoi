import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/providers/auth_providers.dart';
import '../../payments/providers/payment_providers.dart';

/// Page de maintenance pour la version Web de LoueMoi.
///
/// Elle gère deux rôles essentiels :
/// 1. Informer les visiteurs que la version web est en refonte et les orienter vers l'APK Android.
/// 2. Gérer de manière irréprochable les retours de paiement Jèko Mobile Money
///    (success, error, cancelled, pending) avec affichage clair du statut,
///    validation en direct via l'API backend, et bouton direct vers l'application mobile.
class WebMaintenanceScreen extends ConsumerStatefulWidget {
  const WebMaintenanceScreen({
    super.key,
    this.paymentStatus,
    this.reference,
  });

  final String? paymentStatus;
  final String? reference;

  @override
  ConsumerState<WebMaintenanceScreen> createState() => _WebMaintenanceScreenState();
}

class _WebMaintenanceScreenState extends ConsumerState<WebMaintenanceScreen> {
  bool _isCheckingLiveStatus = false;
  String? _liveStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPaymentHandling();
    });
  }

  String? _resolveQueryParam(String key) {
    if (key == 'payment' && widget.paymentStatus != null && widget.paymentStatus!.isNotEmpty) {
      return widget.paymentStatus;
    }
    if (key == 'ref' && widget.reference != null && widget.reference!.isNotEmpty) {
      return widget.reference;
    }

    try {
      final goRouterParams = GoRouterState.of(context).uri.queryParameters;
      if (goRouterParams.containsKey(key) && goRouterParams[key]!.isNotEmpty) {
        return goRouterParams[key];
      }
    } catch (_) {}

    if (Uri.base.queryParameters.containsKey(key)) {
      return Uri.base.queryParameters[key];
    }

    if (Uri.base.fragment.isNotEmpty) {
      try {
        final fragUri = Uri.parse(Uri.base.fragment);
        if (fragUri.queryParameters.containsKey(key)) {
          return fragUri.queryParameters[key];
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> _initPaymentHandling() async {
    final payment = _resolveQueryParam('payment')?.toLowerCase();
    final refCode = _resolveQueryParam('ref');

    if (payment == null && refCode == null) return;

    if (payment == 'success') {
      try {
        await ref.read(authControllerProvider.notifier).refreshProfile();
      } catch (_) {}
      ref.invalidate(userSubscriptionStatusProvider);
    }

    if (refCode != null && refCode.isNotEmpty) {
      await _checkLiveSubscription(refCode);
    }
  }

  Future<void> _checkLiveSubscription(String refCode) async {
    if (_isCheckingLiveStatus) return;
    setState(() => _isCheckingLiveStatus = true);

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final checkUrl = '${Env.apiBaseUrl}/api/payments/jeko/return/?ref=${Uri.encodeComponent(refCode)}&check=1';
      final response = await dio.get<Map<String, dynamic>>(checkUrl);
      if (response.statusCode == 200 && response.data != null) {
        final status = response.data?['status']?.toString();
        if (status != null && status.isNotEmpty && mounted) {
          setState(() => _liveStatus = status);
          if (status == 'active') {
            try {
              await ref.read(authControllerProvider.notifier).refreshProfile();
            } catch (_) {}
            ref.invalidate(userSubscriptionStatusProvider);
          }
        }
      }
    } catch (_) {
      // Best-effort : si hors-ligne ou erreur réseau, on préserve l'état de l'URL
    } finally {
      if (mounted) setState(() => _isCheckingLiveStatus = false);
    }
  }

  Future<void> _downloadApk() async {
    final apkUrl = Uri.parse('${Env.apiBaseUrl}/LoueMoi-release.apk');
    try {
      if (await canLaunchUrl(apkUrl)) {
        await launchUrl(apkUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(apkUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le téléchargement de l’APK LoueMoi a été lancé.')),
        );
      }
    }
  }

  Future<void> _contactSupport({String? refCode}) async {
    final message = refCode != null && refCode.isNotEmpty
        ? 'Bonjour LoueMoi, je vous contacte concernant mon paiement d’abonnement (Réf : $refCode).'
        : 'Bonjour LoueMoi, je vous contacte depuis le site web en maintenance.';
    final cleanPhone = Env.supportPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _copyReference(String refCode) {
    Clipboard.setData(ClipboardData(text: refCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Référence $refCode copiée dans le presse-papiers !'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawPayment = _resolveQueryParam('payment')?.toLowerCase();
    final refCode = _resolveQueryParam('ref');

    // Résolution finale de l'état de paiement
    final bool isSuccess = _liveStatus == 'active' || rawPayment == 'success';
    final bool isFailed = _liveStatus == 'failed' || rawPayment == 'error' || rawPayment == 'cancelled';
    final bool isPending = !isSuccess && !isFailed && (rawPayment == 'pending' || _liveStatus == 'pending');
    final bool hasPaymentContext = isSuccess || isFailed || isPending || (rawPayment != null && rawPayment.isNotEmpty);

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

                  // 2. Si un retour de paiement est détecté, afficher en priorité la carte dédiée
                  if (hasPaymentContext) ...[
                    _buildPaymentResultCard(
                      isSuccess: isSuccess,
                      isFailed: isFailed,
                      isPending: isPending,
                      refCode: refCode,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 3. Carte principale de Maintenance
                  _buildMaintenanceCard(),

                  const SizedBox(height: 20),

                  // 4. Support et assistance WhatsApp
                  InkWell(
                    onTap: () => _contactSupport(refCode: refCode),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.headset_mic_outlined, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Une question ? Contacter l’équipe LoueMoi sur WhatsApp (${Env.supportPhoneDisplay})',
                            style: const TextStyle(
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

                  // 5. Copyright
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

  /// Carte spéciale dédiée à la confirmation ou au suivi du paiement
  Widget _buildPaymentResultCard({
    required bool isSuccess,
    required bool isFailed,
    required bool isPending,
    required String? refCode,
  }) {
    Color cardBorderColor;
    Color accentColor;
    Color lightBgColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (isSuccess) {
      cardBorderColor = const Color(0xFF86EFAC);
      accentColor = const Color(0xFF16A34A);
      lightBgColor = const Color(0xFFF0FDF4);
      statusIcon = Icons.verified_rounded;
      statusTitle = 'Paiement confirmé avec succès !';
      statusSubtitle = 'Votre abonnement mensuel et votre badge de profil certifié sont désormais actifs pour 30 jours.';
    } else if (isFailed) {
      cardBorderColor = const Color(0xFFFECDD3);
      accentColor = const Color(0xFFDC2626);
      lightBgColor = const Color(0xFFFFF1F2);
      statusIcon = Icons.highlight_off_rounded;
      statusTitle = 'Paiement non abouti ou annulé';
      statusSubtitle = 'La transaction a été interrompue. Rassurez-vous, aucun montant n’a été débité de votre compte Mobile Money.';
    } else {
      cardBorderColor = const Color(0xFFBAE6FD);
      accentColor = const Color(0xFF0284C7);
      lightBgColor = const Color(0xFFF0F9FF);
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Paiement en cours de validation';
      statusSubtitle = 'Votre transaction Mobile Money est en attente de validation par votre opérateur. Dès réception, votre abonnement sera activé.';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bandeau haut coloré
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: lightBgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
              border: Border(bottom: BorderSide(color: cardBorderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: accentColor, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isSuccess
                        ? 'TRANSACTION RÉUSSIE'
                        : isFailed
                            ? 'TRANSACTION NON FINALISÉE'
                            : 'TRANSACTION EN COURS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icône principale agrandie
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: lightBgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: cardBorderColor, width: 2),
                  ),
                  child: Center(
                    child: Icon(statusIcon, size: 44, color: accentColor),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  statusTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  statusSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),

                // Référence de paiement avec bouton copier
                if (refCode != null && refCode.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _copyReference(refCode),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Réf : $refCode',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],

                // Si succès : liste des avantages débloqués
                if (isSuccess) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Vos privilèges sont désormais actifs :',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 10),
                        _BenefitRow(
                          icon: Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          text: 'Badge officiel de certification activé sur votre profil',
                        ),
                        SizedBox(height: 6),
                        _BenefitRow(
                          icon: Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          text: 'Déverrouillage des appels et contacts WhatsApp directs',
                        ),
                        SizedBox(height: 6),
                        _BenefitRow(
                          icon: Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          text: 'Messagerie prioritaire et visibilité renforcée',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Message d'orientation vers l'application mobile
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La version Web étant actuellement en maintenance pour modernisation, profitez de votre compte certifié directement dans l’application mobile Android LoueMoi.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF92400E),
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Si en attente : bouton rafraîchir
                if (isPending && refCode != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isCheckingLiveStatus ? null : () => _checkLiveSubscription(refCode),
                    icon: _isCheckingLiveStatus
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _isCheckingLiveStatus ? 'Vérification...' : 'Actualiser le statut',
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Bouton principal pour ouvrir / télécharger l'application mobile
                _buildApkButton(
                  title: isSuccess
                      ? 'Ouvrir mon compte dans l’App LoueMoi'
                      : 'Télécharger l’App LoueMoi (APK)',
                  subtitle: isSuccess
                      ? 'Retrouvez votre abonnement actif et tous vos avantages'
                      : 'Accédez à toutes les annonces et fonctionnalités 100% opérationnelles',
                  isHighlighted: isSuccess,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte principale de présentation de la maintenance web
  Widget _buildMaintenanceCard() {
    return Container(
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
                width: 90,
                height: 90,
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
                    size: 44,
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

          const SizedBox(height: 24),

          const Text(
            'Plateforme Web en cours de maintenance',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
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
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 18),

          // Section Application Mobile opérationnelle
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

          const SizedBox(height: 18),

          // Bouton Télécharger l'APK
          _buildApkButton(
            title: 'Télécharger l’App Android (APK)',
            subtitle: 'Recherchez, visitez et contactez sans interruption',
            isHighlighted: false,
          ),
        ],
      ),
    );
  }

  /// Bouton stylisé pour le téléchargement de l'APK
  Widget _buildApkButton({
    required String title,
    required String subtitle,
    required bool isHighlighted,
  }) {
    final gradientColors = isHighlighted
        ? const [Color(0xFF047857), Color(0xFF10B981)]
        : const [Color(0xFF0F766E), Color(0xFF009688)];

    final shadowColor = isHighlighted ? const Color(0xFF10B981) : const Color(0xFF009688);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _downloadApk,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'APPLICATION SMARTPHONE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.download_rounded,
                size: 24,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
