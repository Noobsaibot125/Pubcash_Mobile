import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pub_cash_mobile/services/auth_service.dart';
import 'package:pub_cash_mobile/screens/profile/profile_update_screen.dart';
import 'package:pub_cash_mobile/utils/app_colors.dart';
import 'package:pub_cash_mobile/widgets/custom_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: user.photoUrl != null
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                    backgroundColor: AppColors.primary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 24),
                _buildProfileInfoItem('Nom d\'utilisateur', user.nomUtilisateur),
                _buildProfileInfoItem('Email', user.email),
                _buildProfileInfoItem('Téléphone', user.contact ?? 'Non renseigné'),
                const SizedBox(height: 40),
                 CustomButton(
                  text: 'Modifier le profil',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileUpdateScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Déconnexion',
                  onPressed: () async {
                    await authService.logout();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  backgroundColor: Colors.red.shade700,
                ),
              ],
            ),
    );
  }

  Widget _buildProfileInfoItem(String label, String value) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
