import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/formatters.dart';
import 'circular_icon_button.dart';

/// Bouton de partage natif Android/iOS enrichi (nom, prix, localisation, lien LoueMoi).
class ShareButton extends StatelessWidget {
  const ShareButton({
    super.key,
    required this.title,
    required this.price,
    required this.location,
    this.propertyId,
  });

  final String title;
  final double price;
  final String location;
  final String? propertyId;

  @override
  Widget build(BuildContext context) {
    return CircularIconButton(
      icon: Icons.ios_share_rounded,
      onTap: () {
        HapticFeedback.lightImpact();
        final link = propertyId != null
            ? 'https://transfert-online.site/properties/$propertyId'
            : 'https://transfert-online.site';
        Share.share(
          '🏡 *$title*\n'
          '💰 ${Formatters.price(price)}\n'
          '📍 $location\n\n'
          '👉 Retrouvez toutes les photos et détails sur LoueMoi :\n'
          '$link',
        );
      },
    );
  }
}
