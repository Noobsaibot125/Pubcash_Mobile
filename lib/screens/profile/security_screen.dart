import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import 'package:flutter/services.dart';
import '../../utils/colors.dart'; // Assure-toi d'importer tes couleurs si besoin

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // (Je garde ta logique changePassword ici)
  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Les mots de passe ne correspondent pas"), backgroundColor: Colors.red));
      return;
    }
    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      await Provider.of<AuthService>(context, listen: false).updateUserProfile(
        nom: user?.nom ?? '',
        prenom: user?.prenom ?? '',
        nomUtilisateur: user?.nomUtilisateur ?? '',
        contact: user?.contact ?? '',
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mot de passe modifié !"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}"), backgroundColor: Colors.red));
      }
    }
  }
  
  // Suppression de initState et dispose pour SystemChrome car on utilise AnnotatedRegion

  @override
  Widget build(BuildContext context) {
    // 1. Force le style BLANC
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Sécurité", style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        // 2. SafeArea protège le bas de page
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Changer le mot de passe", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                CustomTextField(hintText: "Mot de passe actuel", controller: _currentPasswordController, prefixIcon: Icons.lock, obscureText: true),
                CustomTextField(hintText: "Nouveau mot de passe", controller: _newPasswordController, prefixIcon: Icons.lock_outline, obscureText: true),
                CustomTextField(hintText: "Confirmer le nouveau", controller: _confirmPasswordController, prefixIcon: Icons.lock_outline, obscureText: true),
                const SizedBox(height: 30),
                CustomButton(text: "METTRE À JOUR", onPressed: _changePassword),
              ],
            ),
          ),
        ),
      ),
    );
  }
}