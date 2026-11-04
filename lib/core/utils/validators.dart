/// Validateurs de formulaire centralisés (login, inscription, filtres...).
class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 15) {
      return 'Numéro de téléphone invalide';
    }
    // Numéro ivoirien local commençant par 0 (plan à 10 chiffres)
    if (digits.startsWith('0') && digits.length != 10) {
      return 'Le numéro doit comporter 10 chiffres (ex: 0701020304)';
    }
    return null;
  }

  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 15) {
      return 'Numéro de téléphone invalide';
    }
    if (digits.startsWith('0') && digits.length != 10) {
      return 'Le numéro doit comporter 10 chiffres (ex: 0701020304)';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }
    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  static String? required(String? value, {String message = 'Ce champ est requis'}) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }
}
