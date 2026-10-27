/// Validateurs de formulaire centralisés (login, inscription, filtres...).
class Validators {
  Validators._();

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      return 'Numéro de téléphone invalide';
    }
    return null;
  }

  static String? optionalPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      return 'Numéro de téléphone invalide';
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
