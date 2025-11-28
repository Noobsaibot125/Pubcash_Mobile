import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart'; // Assure-toi d'avoir une méthode updateProfile ici ou ApiService

class EditProfileModal extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileModal({super.key, required this.userData});

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomCtrl;
  late TextEditingController _prenomCtrl;
  late TextEditingController _contactCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.userData['nom'] ?? '');
    _prenomCtrl = TextEditingController(text: widget.userData['prenom'] ?? '');
    _contactCtrl = TextEditingController(text: widget.userData['contact'] ?? '');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Appel via AuthService qui appelle l'API
      // Note: Tu dois ajouter updateProfile dans ton AuthService si ce n'est pas fait
      final auth = Provider.of<AuthService>(context, listen: false);
      
      // Simuler l'appel API ou utiliser apiService directement
      // await auth.updateProfile(...); 
      
      Navigator.pop(context, true); // true = succès, recharger le profil
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour !")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // Pour le clavier
        left: 20, right: 20, top: 20
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Modifier le profil", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomCtrl,
              decoration: const InputDecoration(labelText: "Nom", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _prenomCtrl,
              decoration: const InputDecoration(labelText: "Prénom", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(labelText: "Contact", border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading ? const CircularProgressIndicator() : const Text("Enregistrer"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}