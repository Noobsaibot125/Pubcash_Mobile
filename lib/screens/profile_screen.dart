import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import 'history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Contrôleurs pour l'édition des infos
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactController = TextEditingController();

  // Contrôleurs pour le changement de mot de passe
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).refreshUserProfile();
    });
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _usernameController.dispose();
    _contactController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- 1. GESTION PHOTO DE PROFIL ---
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Photo de profil mise à jour !"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur upload: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- 2. MODAL : INFORMATIONS PERSONNELLES ---
  void _showEditInfoSheet(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _nomController.text = user?.nom ?? '';
    _prenomController.text = user?.prenom ?? '';
    _usernameController.text = user?.nomUtilisateur ?? '';
    _contactController.text = user?.contact ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Informations personnelles",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Mettez à jour vos informations.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),

            CustomTextField(
              hintText: "Nom",
              controller: _nomController,
              prefixIcon: Icons.person_outline,
            ),
            CustomTextField(
              hintText: "Prénom",
              controller: _prenomController,
              prefixIcon: Icons.person_outline,
            ),
            CustomTextField(
              hintText: "Nom d'utilisateur",
              controller: _usernameController,
              prefixIcon: Icons.alternate_email,
              readOnly: true, // Désactivé pour tout le monde (comme sur le web)
            ),
            CustomTextField(
              hintText: "Téléphone",
              controller: _contactController,
              prefixIcon: Icons.phone_android,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 20),
            CustomButton(
              text: "ENREGISTRER",
              onPressed: () {
                if (_nomController.text.trim().isEmpty || 
                    _prenomController.text.trim().isEmpty || 
                    _usernameController.text.trim().isEmpty) {
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Le nom, le prénom et le nom d'utilisateur sont obligatoires."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);

                // --- NOUVELLE LOGIQUE INTELLIGENTE ---
                // Si c'est un utilisateur social (Google/FB), on met à jour direct sans demander le mot de passe
                if (user != null && user.isSocialUser) {
                   _handleUpdate(isPasswordChange: false, skipPasswordCheck: true);
                } else {
                   // Sinon (compte classique), on demande le mot de passe
                   _showSecurityCheckDialog(context, isPasswordChange: false);
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- 3. MODAL : SÉCURITÉ ET MOT DE PASSE ---
  void _showChangePasswordSheet(BuildContext context) {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Changer votre mot de passe",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "Mettez à jour vos paramètres de connexion.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),

            const Text(
              "Mot de passe actuel",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            CustomTextField(
              hintText: "Votre mot de passe actuel",
              controller: _currentPasswordController,
              prefixIcon: Icons.lock,
              obscureText: true,
            ),

            const Text(
              "Nouveau mot de passe",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            CustomTextField(
              hintText: "Votre nouveau mot de passe",
              controller: _newPasswordController,
              prefixIcon: Icons.lock_outline,
              obscureText: true,
            ),

            const Text(
              "Confirmer le nouveau mot de passe",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            CustomTextField(
              hintText: "Confirmer le nouveau mdp",
              controller: _confirmPasswordController,
              prefixIcon: Icons.lock_outline,
              obscureText: true,
            ),

            const SizedBox(height: 20),
            CustomButton(
              text: "Changer le mot de passe",
              onPressed: () {
                if (_newPasswordController.text !=
                    _confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Les nouveaux mots de passe ne correspondent pas",
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                _handleUpdate(isPasswordChange: true);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- 4. POPUP DE SÉCURITÉ (Confirmation mot de passe) ---
  void _showSecurityCheckDialog(
    BuildContext context, {
    required bool isPasswordChange,
  }) {
    _currentPasswordController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "Sécurité",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Veuillez entrer votre mot de passe actuel pour confirmer ces modifications.",
            ),
            const SizedBox(height: 15),
            CustomTextField(
              hintText: "Mot de passe actuel",
              controller: _currentPasswordController,
              prefixIcon: Icons.lock,
              obscureText: true,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (_currentPasswordController.text.isEmpty) return;
              Navigator.pop(ctx);
              _handleUpdate(isPasswordChange: isPasswordChange);
            },
            child: const Text(
              "Confirmer",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- LOGIQUE D'ENVOI API ---
  Future<void> _handleUpdate({
    required bool isPasswordChange, 
    bool skipPasswordCheck = false // <--- PARAMÈTRE OPTIONNEL AJOUTÉ
  }) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.currentUser;

      // Si on change le mot de passe, on garde les infos existantes
      String nom = isPasswordChange ? (user?.nom ?? '') : _nomController.text;
      String prenom = isPasswordChange ? (user?.prenom ?? '') : _prenomController.text;
      String username = isPasswordChange ? (user?.nomUtilisateur ?? '') : _usernameController.text;
      String contact = isPasswordChange ? (user?.contact ?? '') : _contactController.text;

      String? newPass = isPasswordChange && _newPasswordController.text.isNotEmpty
          ? _newPasswordController.text
          : null;

      // --- CORRECTION LOGIQUE ---
      // Si skipPasswordCheck est vrai (Google/FB), on envoie une chaîne vide
      // Sinon, on prend ce qu'il y a dans le champ texte
      String currentPassToSend = skipPasswordCheck ? "" : _currentPasswordController.text;

      await auth.updateUserProfile(
        nom: nom,
        prenom: prenom,
        nomUtilisateur: username,
        contact: contact,
        currentPassword: currentPassToSend, 
        newPassword: newPass,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPasswordChange ? "Mot de passe modifié !" : "Profil mis à jour !",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception:', '').trim();
        if (errorMsg.contains("401") || errorMsg.contains("incorrect")) {
          errorMsg = "Mot de passe actuel incorrect.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- DIALOGUE PARRAINAGE (Inchangé) ---
  void _showReferralDialog(BuildContext context, user) {
    final code = user.codeParrainage ?? '...';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_alt_outlined,
              size: 50,
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            const Text(
              "Parrainage",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Invitez vos amis et gagnez des points !",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Code copié !")),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  final String shareUrl =
                      "https://pub-cash.com/auth/register-user?ref=$code";
                  Share.share(
                    "Rejoins PubCash ! Code : $code\nLien : $shareUrl",
                  );
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text(
                  "Inviter un ami",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _logout() {
    Provider.of<AuthService>(context, listen: false).logout();
    // Utiliser le routeur principal pour revenir au login proprement
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ASTUCE POUR FORCER LE RAFRAICHISSEMENT DE L'IMAGE
    String? displayPhotoUrl;
    if (user.photoUrl != null && user.photoUrl!.isNotEmpty) {
       final separator = user.photoUrl!.contains('?') ? '&' : '?';
       displayPhotoUrl = "${user.photoUrl}$separator v=${DateTime.now().millisecondsSinceEpoch}";
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
                          ? const Icon(Icons.person, size: 50, color: Colors.grey) 
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

            // --- INFO HEADER ---
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

            // --- BADGE VÉRIFIÉ ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Vérifié",
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- MENU (DESIGN MAQUETTE) ---
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9FF), // Fond bleuté très léger
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: Icons.person,
                    iconColor: Colors.orange,
                    title: "Informations personnelles",
                    onTap: () => _showEditInfoSheet(context),
                  ),
                  _buildDivider(),

                  // --- Masquer "Sécurité" pour les utilisateurs sociaux ---
                  if (!user.isSocialUser) ...[
                    _ProfileMenuItem(
                      icon: Icons.lock,
                      iconColor: Colors.orange,
                      title: "Sécurité et mot de passe",
                      onTap: () => _showChangePasswordSheet(context),
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
                  
                  // SUPPRIMÉ : Historique de transaction
                  
                  _ProfileMenuItem(
                    icon: Icons.people_alt,
                    iconColor: Colors.blueAccent, // Couleur distincte
                    title: "Parrainage",
                    onTap: () => _showReferralDialog(context, user),
                  ),
                  _buildDivider(),
                  
                  _ProfileMenuItem(
                    icon: Icons.description,
                    iconColor: Colors.orange,
                    title: "Condition générale",
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- MENU BAS (DECONNEXION) ---
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

// --- WIDGET HELPER POUR LE MENU ---
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