import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final IconData? prefixIcon;
  
  // 1. CHANGEMENT : On accepte un Widget (comme IconButton), pas juste une IconData
  final Widget? suffixIcon; 
  
  final bool obscureText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  // On a supprimé 'onSuffixIconTap' car c'est le widget suffixIcon qui gère son propre clic

  const CustomTextField({
    super.key,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2), // Petite correction syntaxe
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          
          // Gère l'icône de gauche (reste une IconData classique)
          prefixIcon: prefixIcon != null 
              ? Icon(prefixIcon, color: AppColors.primary) 
              : null,
          
          // 2. CHANGEMENT : On affiche directement le widget (le bouton oeil)
          suffixIcon: suffixIcon, 
          
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder( // Ajout pour garder le style si erreur et focus
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
    );
  }
}