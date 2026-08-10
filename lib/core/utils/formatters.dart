import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

/// Formatage centralisé des prix et dates, pour ne jamais dupliquer la
/// logique d'affichage ("450.000Fcfa", "il y a 3h"...).
class Formatters {
  Formatters._();

  static final NumberFormat _priceFormat = NumberFormat.decimalPattern('fr_FR');

  static String price(double value) {
    final formatted = _priceFormat.format(value).replaceAll(RegExp(r'[\s ]'), '.');
    return '$formatted${AppConstants.currencySuffix}';
  }

  static String priceWithoutSuffix(double value) {
    return _priceFormat.format(value).replaceAll(RegExp(r'[\s ]'), '.');
  }

  static String relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) return '$weeks sem';
    final months = (diff.inDays / 30).floor();
    return '$months mois';
  }

  static String relativeTimeWithPrefix(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 7) return 'Il y a ${relativeTime(dateTime)}';
    return 'Il y a ${relativeTime(dateTime)}';
  }

  static String shortDate(DateTime dateTime) {
    return DateFormat('d MMM', 'fr_FR').format(dateTime);
  }
}
