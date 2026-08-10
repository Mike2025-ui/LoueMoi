import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/formatters.dart';
import 'circular_icon_button.dart';

/// Bouton de partage natif Android/iOS (nom, prix, localisation de l'annonce).
class ShareButton extends StatelessWidget {
  const ShareButton({
    super.key,
    required this.title,
    required this.price,
    required this.location,
  });

  final String title;
  final double price;
  final String location;

  @override
  Widget build(BuildContext context) {
    return CircularIconButton(
      icon: Icons.ios_share_rounded,
      onTap: () {
        Share.share('$title\n${Formatters.price(price)}\n$location');
      },
    );
  }
}
