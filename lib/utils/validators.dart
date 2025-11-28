import 'package:email_validator/email_validator.dart';

class Validators {
  // Validation email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    if (!EmailValidator.validate(value)) {
      return 'Email invalide';
    }
    return null;
  }

  // Validation mot de passe
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    return null;
  }

  // Validation confirmation mot de passe
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }
    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  // Validation champ requis
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  // Validation téléphone
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    // Regex simple pour téléphone (10 chiffres)
    if (!RegExp(r'^\d{10}$').hasMatch(value.replaceAll(RegExp(r'\s+'), ''))) {
      return 'Numéro de téléphone invalide (10 chiffres)';
    }
    return null;
  }
}
