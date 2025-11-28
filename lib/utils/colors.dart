import 'package:flutter/material.dart';

// Couleurs PubCash
class AppColors {
  // Couleurs principales
  static const Color primary = Color(0xFFfb6340);
  static const Color secondary = Color(0xFF11cdef);
  static const Color success = Color(0xFF2dce89);
  static const Color dark = Color(0xFF172b4d);
  static const Color light = Color(0xFFf7fafc);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFfb6340), Color(0xFFff6b9d)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Couleurs de texte
  static const Color textDark = Color(0xFF32325d);
  static const Color textMuted = Color(0xFF525f7f);
  static const Color textLight = Color(0xFFadb5bd);
}
