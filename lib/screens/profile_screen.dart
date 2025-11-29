import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart'; // Pour le clipboard
import '../services/auth_service.dart';
import '../utils/colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_overlay.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Onglets
  int _selectedIndex = 0; // 0 = Infos, 1 = Parrainage

  // Contrôleurs pour l'édition
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactController = TextEditingController();
  
  // Pour la confirmation
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Charger les données dès l'ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthService>(context, listen: false).refreshUserProfile();
    });
  }

  void _initControllers(user) {
    _nomController.text = user?.nom ?? '';
    _prenomController.text = user?.prenom ?? '';
    _usernameController.text = user?.nomUtilisateur ?? '';
    _contactController.text = user?.contact ?? '';
  }

  // --- ACTIONS ---

  void _shareCode(String code) {
    final String shareUrl = "https://pub-cash.com/auth/register-user?ref=$code";
    final String message = "Rejoins PubCash et gagne de l'argent ! Inscris-toi avec mon code : $code\n\nLien : $shareUrl";
    Share.share(message);
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copié !")));
  }

  void _showEditProfileDialog(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _initControllers(user);
    _currentPasswordController.clear();
    _newPasswordController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Modifier mon profil"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(hintText: "Nom", controller: _nomController, prefixIcon: Icons.person),
              CustomTextField(hintText: "Prénom", controller: _prenomController, prefixIcon: Icons.person),
              CustomTextField(hintText: "Nom d'utilisateur", controller: _usernameController, prefixIcon: Icons.alternate_email),
              CustomTextField(hintText: "Contact", controller: _contactController, prefixIcon: Icons.phone, keyboardType: TextInputType.phone),
              const Divider(),
              const Text("Sécurité (Requis pour valider)", style: TextStyle(fontSize: 12, color: Colors.grey)),
              CustomTextField(hintText: "Mot de passe ACTUEL", controller: _currentPasswordController, prefixIcon: Icons.lock, obscureText: true),
              CustomTextField(hintText: "Nouveau mot de passe (Optionnel)", controller: _newPasswordController, prefixIcon: Icons.lock_open, obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (_currentPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mot de passe actuel requis"), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(ctx);
              _handleUpdate();
            },
            child: const Text("Enregistrer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpdate() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      await auth.updateUserProfile(
        nom: _nomController.text,
        prenom: _prenomController.text,
        nomUtilisateur: _usernameController.text,
        contact: _contactController.text,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text.isNotEmpty ? _newPasswordController.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour avec succès !"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red));
      }
    }
  }

  void _logout() {
    Provider.of<AuthService>(context, listen: false).logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Mon Profil", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: AppColors.primary), onPressed: () => _showEditProfileDialog(context)),
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER PROFILE
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(user.photoUrl ?? 'https://via.placeholder.com/150'),
                    backgroundColor: Colors.grey[200],
                  ),
                  const SizedBox(height: 10),
                  Text(user.nomUtilisateur, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("${user.commune ?? ''} - ${user.points} Pts", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // TABS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton("Informations", 0),
                const SizedBox(width: 15),
                _buildTabButton("Parrainage", 1),
              ],
            ),
            const SizedBox(height: 20),

            // CONTENU
            _selectedIndex == 0 ? _buildInfoSection(user) : _buildReferralSection(user),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    bool isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [if (!isActive) const BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Text(title, style: TextStyle(color: isActive ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoSection(user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildInfoRow("Nom complet", "${user.prenom ?? ''} ${user.nom ?? ''}"),
              _buildInfoRow("Email", user.email),
              _buildInfoRow("Téléphone", user.contact ?? 'Non renseigné'),
              _buildInfoRow("Commune", user.commune ?? 'Non renseignée'),
              _buildInfoRow("Date naissance", user.dateNaissance ?? ''),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReferralSection(user) {
    final code = user.codeParrainage ?? '...';
    // Utilisation de la liste des filleuls si disponible (nécessite mise à jour du modèle User)
    final referrals = user.referrals ?? []; 

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("Mon Code Parrainage", style: TextStyle(fontSize: 16, color: AppColors.primary)),
                  const SizedBox(height: 10),
                  Text(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _shareCode(code),
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text("Inviter", style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.grey),
                        onPressed: () => _copyCode(code),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text("Mes Filleuls", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(height: 10),
          
          if (referrals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text("Aucun filleul pour le moment.", style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: referrals.length,
              itemBuilder: (ctx, i) {
                final ref = referrals[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    title: Text(ref['nom_utilisateur'] ?? 'Inconnu'),
                    subtitle: Text("Inscrit le: ${ref['date_inscription'] != null ? ref['date_inscription'].toString().substring(0,10) : ''}"),
                    trailing: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}