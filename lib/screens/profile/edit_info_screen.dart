import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Remonte de 2 niveaux pour trouver services et widgets
import '../../services/auth_service.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../utils/colors.dart'; // Assure-toi d'avoir importé tes couleurs

class EditInfoScreen extends StatefulWidget {
  const EditInfoScreen({super.key});

  @override
  State<EditInfoScreen> createState() => _EditInfoScreenState();
}

class _EditInfoScreenState extends State<EditInfoScreen> {
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordCheckController = TextEditingController();
  
  bool _isLoading = false; // Pour afficher un chargement pendant l'envoi

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark, // icônes noires
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null) {
      _nomController.text = user.nom ?? '';
      _prenomController.text = user.prenom ?? '';
      _usernameController.text = user.nomUtilisateur ?? '';
      _contactController.text = user.contact ?? '';
    }
  }
  

  @override
  void dispose() {
    // Restaure le style global
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
    _nomController.dispose();
    _prenomController.dispose();
    _usernameController.dispose();
    _contactController.dispose();
    _passwordCheckController.dispose();
    super.dispose();
  }

  // --- 1. POPUP DE SUCCÈS ---
 void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Column(
          children: const [
             Icon(Icons.check_circle, color: Colors.green, size: 50),
             SizedBox(height: 10),
             Text("Succès", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Vos informations ont été mises à jour avec succès.",
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Column(
          children: const [
             Icon(Icons.error_outline, color: Colors.red, size: 50),
             SizedBox(height: 10),
             Text("Erreur", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Fermer", style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveInfo() async {
    if (_nomController.text.trim().isEmpty || 
        _prenomController.text.trim().isEmpty || 
        _usernameController.text.trim().isEmpty) {
      _showErrorDialog("Veuillez remplir les champs obligatoires.");
      return;
    }
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user != null && user.isSocialUser) {
      await _performUpdate(skipPasswordCheck: true);
    } else {
      _showSecurityCheckDialog();
    }
  }

  Future<void> _performUpdate({bool skipPasswordCheck = false}) async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).updateUserProfile(
        nom: _nomController.text,
        prenom: _prenomController.text,
        nomUtilisateur: _usernameController.text,
        contact: _contactController.text,
        currentPassword: skipPasswordCheck ? "" : _passwordCheckController.text,
        newPassword: null,
      );
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString();
        if (errorMsg.contains("401") || errorMsg.toLowerCase().contains("unauthorized")) {
           errorMsg = "Le mot de passe actuel est incorrect.";
        } else {
           errorMsg = errorMsg.replaceAll("Exception:", "").trim();
        }
        _showErrorDialog(errorMsg);
      }
    }
  }

  void _showSecurityCheckDialog() {
    _passwordCheckController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Sécurité", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Confirmez votre mot de passe actuel."),
            const SizedBox(height: 15),
            CustomTextField(
              hintText: "Mot de passe actuel",
              controller: _passwordCheckController,
              obscureText: true,
              prefixIcon: Icons.lock,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (_passwordCheckController.text.isEmpty) return;
              Navigator.pop(ctx);
              _performUpdate(skipPasswordCheck: false);
            },
            child: const Text("Confirmer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  // --- FIN DES FONCTIONS COPIEES ---

  @override
  Widget build(BuildContext context) {
    // 1. Force le style BLANC ici
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white, // Fond BLANC
        systemNavigationBarIconBrightness: Brightness.dark, // Icônes noires
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Informations personnelles", style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        body: SafeArea( // 2. SafeArea protège le bas de page
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CustomTextField(hintText: "Nom", controller: _nomController, prefixIcon: Icons.person_outline),
                    CustomTextField(hintText: "Prénom", controller: _prenomController, prefixIcon: Icons.person_outline),
                    CustomTextField(hintText: "Nom d'utilisateur", controller: _usernameController, prefixIcon: Icons.alternate_email, readOnly: true),
                    CustomTextField(hintText: "Téléphone", controller: _contactController, prefixIcon: Icons.phone_android, keyboardType: TextInputType.phone),
                    const SizedBox(height: 30),
                    CustomButton(text: "ENREGISTRER", onPressed: _saveInfo),
                  ],
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}