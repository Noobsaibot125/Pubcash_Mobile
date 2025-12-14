import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user.dart';
// --- IMPORTS VERS LE DOSSIER PROFILE ---
import 'profile/edit_info_screen.dart';
import 'profile/security_screen.dart';
import 'profile/referral_screen.dart';
import 'profile/terms_screen.dart';
import 'profile/contact_screen.dart'; // N'oublie pas de créer celui-ci si tu veux la page vide
import 'history_screen.dart'; // Si history est dans le même dossier screen/

import '../services/auth_service.dart';
import '../utils/colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _imageVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).refreshUserProfile();
    });
  }

  Future<void> _handleImagePick() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      try {
        await Provider.of<AuthService>(
          context,
          listen: false,
        ).uploadProfileImage(File(image.path));

        if (mounted) {
          setState(() {
            _imageVersion++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Photo mise à jour !"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
void _showDeleteAccountDialog(BuildContext context, User user) {
    final TextEditingController passwordController = TextEditingController();
    // Vérifier si l'utilisateur s'est connecté via Email (nécessite MDP) ou Social (Pas de MDP)
    // On suppose que tu as un moyen de savoir ça, sinon on demande le MDP seulement si user.password est set (logique frontend)
    bool requiresPassword = user.idGoogle == null && user.idFacebook == null; 

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer le compte ?", style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Votre compte sera supprimé définitivement après 45 jours. Vous pouvez le réactiver à tout moment en vous reconnectant avant ce délai.",
              style: TextStyle(fontSize: 14),
            ),
            if (requiresPassword) ...[
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Entrez votre mot de passe",
                  border: OutlineInputBorder(),
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (requiresPassword && passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Mot de passe requis")),
                );
                return;
              }
              
              // Appel API
              try {
                await Provider.of<AuthService>(context, listen: false).deleteAccount(
                  password: requiresPassword ? passwordController.text : null,
                  authProvider: requiresPassword ? 'email' : 'social'
                );
                Navigator.of(ctx).pop(); // Ferme la modale
                _logout(); // Déconnecte l'utilisateur
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Demande de suppression prise en compte.")),
                );
              } catch (e) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  void _logout() {
    Provider.of<AuthService>(context, listen: false).logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
 
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String? displayPhotoUrl;
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
      final separator = user.photoUrl!.contains('?') ? '&' : '?';
      displayPhotoUrl = "${user.photoUrl}$separator v=$_imageVersion";
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mon Profil",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // --- AVATAR ---
            GestureDetector(
              onTap: _handleImagePick,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: displayPhotoUrl != null
                          ? NetworkImage(displayPhotoUrl)
                          : null,
                      child: displayPhotoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(blurRadius: 5, color: Colors.black26),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            Text(
              "${user.prenom ?? ''} ${user.nom ?? ''}".trim().isEmpty
                  ? user.nomUtilisateur
                  : "${user.prenom} ${user.nom}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              user.email,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 10),

            // --- MODIFICATION ICI : AFFICHER LA COMMUNE ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                // Fond bleu clair au lieu de vert
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.blue, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    // Affiche la commune ou un texte par défaut
                    user.commune ?? "Commune inconnue",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9FF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: Icons.person,
                    iconColor: Colors.orange,
                    title: "Informations personnelles",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditInfoScreen()),
                    ),
                  ),
                  _buildDivider(),

                  // --- LOGIQUE POUR CACHER LA SÉCURITÉ ---
                  // Cela fonctionnera maintenant que le backend envoie id_google/id_facebook
                  if (!user.isSocialUser) ...[
                    _ProfileMenuItem(
                      icon: Icons.lock,
                      iconColor: Colors.orange,
                      title: "Sécurité et mot de passe",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityScreen(),
                        ),
                      ),
                    ),
                    _buildDivider(),
                  ],
                  _ProfileMenuItem(
                    icon: Icons.history,
                    iconColor: Colors.orange,
                    title: "Historique",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  _buildDivider(),

                  _ProfileMenuItem(
                    icon: Icons.people_alt,
                    iconColor: Colors.blueAccent,
                    title: "Parrainage",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReferralScreen()),
                    ),
                  ),
                  _buildDivider(),

                  _ProfileMenuItem(
                    icon: Icons.contact_support, // Icone plus appropriée
                    iconColor:
                        Colors.blueAccent, // Couleur en accord avec le reste
                    title: "Contactez-nous",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactScreen()),
                    ),
                  ),
                  _buildDivider(),

                  _ProfileMenuItem(
                    icon: Icons.description,
                    iconColor: Colors.orange,
                    title: "Conditions générales",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
_ProfileMenuItem(
              icon: Icons.delete_forever,
              iconColor: Colors.red,
              title: "Supprimer mon compte",
              textColor: Colors.red,
              hideChevron: true,
              onTap: () => _showDeleteAccountDialog(context, user),
            ),
            
            const SizedBox(height: 10), // Petit espace
            _ProfileMenuItem(
              icon: Icons.logout,
              iconColor: Colors.red,
              title: "Se déconnecter",
              textColor: Colors.red,
              hideChevron: true,
              onTap: _logout,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 60,
      endIndent: 20,
      color: Colors.black12,
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  final Color textColor;
  final bool hideChevron;

  const _ProfileMenuItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.textColor = Colors.black87,
    this.hideChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: textColor,
        ),
      ),
      trailing: hideChevron
          ? null
          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
    );
  }
 
}
