import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pub_cash_mobile/services/auth_service.dart';
import 'package:pub_cash_mobile/widgets/custom_button.dart';
import 'package:pub_cash_mobile/widgets/custom_text_field.dart';
import 'package:pub_cash_mobile/utils/app_colors.dart';

class ProfileUpdateScreen extends StatefulWidget {
  const ProfileUpdateScreen({super.key});

  @override
  _ProfileUpdateScreenState createState() => _ProfileUpdateScreenState();
}

class _ProfileUpdateScreenState extends State<ProfileUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomUtilisateurController;
  late TextEditingController _contactController;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _nomUtilisateurController = TextEditingController(text: user?.nomUtilisateur);
    _contactController = TextEditingController(text: user?.contact);
  }

  @override
  void dispose() {
    _nomUtilisateurController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final authService = Provider.of<AuthService>(context, listen: false);
      try {
        await authService.updateProfile(
          nom: _nomUtilisateurController.text,
          prenom: '', // Prénom is not in the model, but the service expects it.
          telephone: _contactController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(
                controller: _nomUtilisateurController,
                labelText: 'Nom d\'utilisateur',
                validator: (value) => value!.isEmpty ? 'Veuillez entrer votre nom d\'utilisateur' : null,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _contactController,
                labelText: 'Téléphone',
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? 'Veuillez entrer votre téléphone' : null,
              ),
              const SizedBox(height: 40),
              CustomButton(
                text: 'Mettre à jour',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
