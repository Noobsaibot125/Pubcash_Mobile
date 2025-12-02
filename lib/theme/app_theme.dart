import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Nécessaire pour SystemUiOverlayStyle
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // Force la clarté générale (aide Android à choisir les bonnes couleurs d'icônes)
      brightness: Brightness.light, 
      
      colorScheme: const ColorScheme.light( // Ajout de const pour optimiser
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Colors.white,
        // On s'assure que le fond est bien blanc
        background: Colors.white, 
      ),
      
      // Couleur de fond générale des Scaffolds
      scaffoldBackgroundColor: Colors.white,

      // --- AJOUT IMPORTANT : GESTION DE LA BARRE DU HAUT ---
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black), // Flèche retour noire
        actionsIconTheme: IconThemeData(color: Colors.black), // Icônes d'actions noires
        titleTextStyle: TextStyle(
          color: Colors.black, 
          fontSize: 20, 
          fontWeight: FontWeight.bold
        ),
        // Force les icônes de la barre de statut (batterie, heure) en NOIR
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Pour Android
          statusBarBrightness: Brightness.light,    // Pour iOS
        ),
      ),

      // Typographie avec Google Fonts
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: AppColors.textDark),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F5F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          // CORRECTION: withOpacity au lieu de withValues pour compatibilité
          shadowColor: AppColors.primary.withOpacity(0.4), 
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // CORRECTION: withOpacity ici aussi
        shadowColor: Colors.black.withOpacity(0.1),
        color: Colors.white, // S'assurer que les cartes sont blanches
      ),
    );
  }
}