import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart'; // Pour le clipboard
import 'package:share_plus/share_plus.dart';
import '../utils/colors.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }
void _showShareReferralModal(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Inviter des amis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text("Votre code : $code", style: const TextStyle(fontSize: 24, color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(Icons.copy, "Copier", () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copié !")));
                }),
                _buildShareButton(Icons.share, "Partager", () {
                  Share.share("Rejoins PubCash avec mon code : $code et gagne de l'argent ! https://pub-cash.com");
                  Navigator.pop(context);
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.secondary.withOpacity(0.1),
            child: Icon(icon, color: AppColors.secondary),
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
  Future<void> _loadProfile() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final data = await authService.getUserProfile();
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur chargement profil: $e')));
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur déconnexion: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_profileData == null) {
      return const Scaffold(
        body: Center(child: Text("Impossible de charger le profil")),
      );
    }

    final user = _profileData!;
    final referrals = user['referrals'] as List<dynamic>? ?? [];

    // --- CORRECTION URL PHOTO ---
    // On sécurise l'URL de la photo pour éviter les objets bizarres
    final String? photoUrl = user['photo_profil']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        image: DecorationImage(
                          image: photoUrl != null && photoUrl.startsWith('http')
                              ? CachedNetworkImageProvider(photoUrl)
                              : const AssetImage(
                                      'assets/images/placeholder_profile.png')
                                  as ImageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      // CORRECTION : .toString() pour éviter le crash Map
                      user['nom_utilisateur']?.toString() ?? 'Utilisateur',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      // CORRECTION : .toString() ici aussi
                      user['commune_choisie']?.toString() ?? 'Commune non définie',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte Informations
                  _buildSectionCard(
                    title: 'Informations Personnelles',
                    icon: Icons.person,
                    children: [
                      // CORRECTION : On sécurise chaque champ avec .toString()
                      _buildInfoRow('Email', user['email']?.toString()),
                      _buildInfoRow(
                        'Contact',
                        user['contact']?.toString() ?? 'Non renseigné',
                      ),
                      _buildInfoRow(
                        'Date de naissance',
                        user['date_naissance'] != null
                            ? user['date_naissance'].toString().split('T')[0]
                            : 'Non renseignée',
                      ),
                      // Ajoutons le genre pour être complet
                      _buildInfoRow('Genre', user['genre']?.toString()),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Carte Parrainage
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.rocket_launch,
                              color: AppColors.secondary,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Espace Parrainage',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            // CORRECTION : .toString() ici
                            user['code_parrainage']?.toString() ?? '...',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Partagez ce code pour gagner des points !',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: () {
         final code = user['code_parrainage']?.toString() ?? '';
         if (code.isNotEmpty) _showShareReferralModal(code);
      },
                            icon: const Icon(Icons.share),
                            label: const Text('Inviter des amis'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Liste Filleuls
                  if (referrals.isNotEmpty)
                    _buildSectionCard(
                      title: 'Mes Filleuls (${referrals.length})',
                      icon: Icons.group,
                      children: referrals.map<Widget>((ref) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(
                                  0.1,
                                ),
                                child: Text(
                                  (ref['nom_utilisateur']?.toString() ?? 'U')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref['nom_utilisateur']?.toString() ??
                                        'Utilisateur',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Inscrit le ${ref['date_inscription']?.toString().split('T')[0] ?? ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 30),

                  // Bouton Déconnexion
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Se déconnecter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(
            // Sécurité supplémentaire ici
            value?.toString() ?? 'Non renseigné',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}