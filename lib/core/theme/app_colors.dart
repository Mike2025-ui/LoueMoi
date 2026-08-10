import 'package:flutter/material.dart';

/// Palette centralisée de l'application. Ne jamais coder une couleur en dur
/// ailleurs dans le code : toujours passer par [AppColors].
class AppColors {
  AppColors._();

  // Couleur principale — indigo/violet vif, identité propre à LoueMoi.
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF4E3FC7);
  static const Color primaryLight = Color(0xFFEFECFD);

  // Accent chaud, à utiliser avec parcimonie (mise en avant, badges spéciaux).
  static const Color accent = Color(0xFFFFB020);

  // Neutres
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5F5F5);
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEDEDED);

  // Texte
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFA0A0A0);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // États positifs / négatifs
  static const Color success = Color(0xFF2E9E44);
  static const Color successBg = Color(0xFFDDF3E0);
  static const Color danger = Color(0xFFE0483E);
  static const Color dangerBg = Color(0xFFFBE0DD);
  static const Color warningBg = Color(0xFFFBE8D6);
  static const Color warningText = Color(0xFFC9791F);

  // Statuts spécifiques annonces
  static const Color statusLocationBg = Color(0xFFDDF3E0);
  static const Color statusLocationText = Color(0xFF2E9E44);
  static const Color statusVenteBg = Color(0xFFFBE8D6);
  static const Color statusVenteText = Color(0xFFC9791F);
  static const Color statusOccupeeBg = Color(0xFFFBE0DD);
  static const Color statusOccupeeText = Color(0xFFD9463C);

  // Favoris
  static const Color favoriteActive = Color(0xFFE0483E);
  static const Color favoriteInactive = Color(0xFF1A1A1A);

  // Overlay / boutons flottants sur images
  static const Color overlayDark = Color(0x99000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
