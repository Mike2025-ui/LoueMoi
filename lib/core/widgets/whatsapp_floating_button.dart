import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/env.dart';

/// Bouton flottant lumineux vert officiel avec logo WhatsApp.
///
/// Affiché exclusivement sur l'écran d'accueil pour permettre aux utilisateurs
/// de contacter instantanément le service client LoueMoi au 07 02 06 52 06.
class WhatsAppFloatingButton extends StatefulWidget {
  const WhatsAppFloatingButton({
    super.key,
    this.phone = Env.supportPhone,
    this.defaultMessage =
        'Bonjour LoueMoi, je souhaite obtenir des renseignements.',
  });

  final String phone;
  final String defaultMessage;

  @override
  State<WhatsAppFloatingButton> createState() => _WhatsAppFloatingButtonState();
}

class _WhatsAppFloatingButtonState extends State<WhatsAppFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    HapticFeedback.mediumImpact();
    final cleanPhone = widget.phone.replaceAll(RegExp(r'[^0-9]'), '');
    final textParam = widget.defaultMessage.isNotEmpty
        ? Uri.encodeComponent(widget.defaultMessage)
        : '';

    final nativeUri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone${textParam.isNotEmpty ? '&text=$textParam' : ''}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$cleanPhone${textParam.isNotEmpty ? '?text=$textParam' : ''}',
    );

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Impossible d’ouvrir WhatsApp. Contactez-nous au ${Env.supportPhoneDisplay}.',
            ),
            backgroundColor: const Color(0xFF128C7E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final progress = _glowAnimation.value;
        final blur = 14.0 + (progress * 10.0);
        final spread = 2.0 + (progress * 4.0);
        final glowAlpha = 0.50 + (progress * 0.25);

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF25D366).withValues(alpha: glowAlpha),
                blurRadius: blur,
                spreadRadius: spread,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: const Color(0xFF128C7E).withValues(alpha: 0.35),
                blurRadius: blur * 1.5,
                spreadRadius: spread * 1.2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Tooltip(
        message: 'Contacter LoueMoi sur WhatsApp (${Env.supportPhoneDisplay})',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openWhatsApp,
            splashColor: Colors.white.withValues(alpha: 0.3),
            highlightColor: Colors.white.withValues(alpha: 0.15),
            child: Ink(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF25D366),
                    Color(0xFF1EBE5D),
                    Color(0xFF128C7E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(32, 32),
                  painter: _WhatsAppLogoPainter(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Peintre vectoriel du logo officiel WhatsApp
class _WhatsAppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Bulle de discussion extérieure
    final bubblePath = Path();
    bubblePath.moveTo(12.04, 2.0);
    bubblePath.cubicTo(6.58, 2.0, 2.13, 6.45, 2.13, 11.91);
    bubblePath.cubicTo(2.13, 13.66, 2.59, 15.36, 3.45, 16.86);
    bubblePath.lineTo(2.05, 22.0);
    bubblePath.lineTo(7.3, 20.62);
    bubblePath.cubicTo(8.75, 21.41, 10.38, 21.83, 12.04, 21.83);
    bubblePath.cubicTo(17.5, 21.83, 21.95, 17.38, 21.95, 11.92);
    bubblePath.cubicTo(21.95, 9.27, 20.92, 6.78, 19.05, 4.91);
    bubblePath.cubicTo(17.18, 3.04, 14.69, 2.0, 12.04, 2.0);
    bubblePath.close();

    // Découpe intérieure
    final innerCut = Path();
    innerCut.moveTo(12.05, 3.67);
    innerCut.cubicTo(14.25, 3.67, 16.31, 4.53, 17.87, 6.09);
    innerCut.cubicTo(19.42, 7.65, 20.28, 9.72, 20.28, 11.92);
    innerCut.cubicTo(20.28, 16.46, 16.58, 20.15, 12.04, 20.15);
    innerCut.cubicTo(10.56, 20.15, 9.11, 19.76, 7.85, 19.0);
    innerCut.lineTo(7.55, 18.83);
    innerCut.lineTo(4.43, 19.65);
    innerCut.lineTo(5.26, 16.61);
    innerCut.lineTo(5.06, 16.29);
    innerCut.cubicTo(4.24, 15.0, 3.8, 13.47, 3.8, 11.91);
    innerCut.cubicTo(3.81, 7.37, 7.5, 3.67, 12.05, 3.67);
    innerCut.close();

    // Combiné téléphonique
    final phonePath = Path();
    phonePath.moveTo(8.53, 7.33);
    phonePath.cubicTo(8.37, 7.33, 8.1, 7.39, 7.87, 7.64);
    phonePath.cubicTo(7.65, 7.89, 7.02, 8.48, 7.02, 9.68);
    phonePath.cubicTo(7.02, 10.88, 7.89, 12.04, 8.01, 12.2);
    phonePath.cubicTo(8.13, 12.37, 9.72, 14.81, 12.16, 15.86);
    phonePath.cubicTo(14.19, 16.74, 14.6, 16.56, 15.05, 16.52);
    phonePath.cubicTo(15.5, 16.48, 16.49, 15.93, 16.7, 15.34);
    phonePath.cubicTo(16.91, 14.75, 16.91, 14.24, 16.85, 14.14);
    phonePath.cubicTo(16.79, 14.04, 16.62, 13.98, 16.37, 13.85);
    phonePath.cubicTo(16.12, 13.73, 14.9, 13.13, 14.67, 13.05);
    phonePath.cubicTo(14.44, 12.97, 14.28, 12.93, 14.11, 13.18);
    phonePath.cubicTo(13.95, 13.43, 13.47, 14.04, 13.33, 14.21);
    phonePath.cubicTo(13.18, 14.37, 13.04, 14.39, 12.79, 14.27);
    phonePath.cubicTo(12.54, 14.14, 11.75, 13.88, 10.8, 13.04);
    phonePath.cubicTo(10.07, 12.38, 9.57, 11.57, 9.43, 11.32);
    phonePath.cubicTo(9.28, 11.07, 9.41, 10.94, 9.54, 10.81);
    phonePath.cubicTo(9.65, 10.7, 9.79, 10.52, 9.92, 10.37);
    phonePath.cubicTo(10.05, 10.22, 10.09, 10.11, 10.17, 9.95);
    phonePath.cubicTo(10.26, 9.78, 10.21, 9.64, 10.15, 9.52);
    phonePath.cubicTo(10.09, 9.39, 9.6, 8.19, 9.39, 7.7);
    phonePath.cubicTo(9.19, 7.21, 8.98, 7.28, 8.83, 7.27);
    phonePath.cubicTo(8.68, 7.27, 8.53, 7.33, 8.53, 7.33);
    phonePath.close();

    // Remplissage de la bulle et du combiné
    canvas.drawPath(bubblePath, whitePaint);

    final greenCutPaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(innerCut, greenCutPaint);
    canvas.drawPath(phonePath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
