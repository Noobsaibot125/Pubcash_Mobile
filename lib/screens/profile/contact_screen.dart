import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Assurez-vous que ces imports existent bien dans votre projet
import '../../services/auth_service.dart';
import '../../services/feedback_service.dart';
import '../../utils/colors.dart';
import 'feedback_detail_screen.dart';

// Si vous n'avez pas url_launcher, vous pouvez retirer les onTap ou ajouter le package plus tard
// import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({Key? key}) : super(key: key);

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final FeedbackService _feedbackService = FeedbackService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 2 Tabs: "Nous joindre" et "Un message". "Un message" est l'index 1.
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        String fullName = "";
        if (user.prenom != null) fullName += user.prenom!;
        if (user.nom != null) {
          fullName += (fullName.isNotEmpty ? " " : "") + user.nom!;
        }

        _nameController.text = fullName.isNotEmpty
            ? fullName
            : (user.nomUtilisateur ?? '');
        _emailController.text = user.email ?? '';
        _phoneController.text = user.contact ?? '';
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _feedbackService.sendFeedback(
        fullName: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
        message: _messageController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback envoyé avec succès !'),
          backgroundColor: AppColors.success,
        ),
      );

      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FeedbackHistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Contactez-nous',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // ZÔNE DES ONGLETS (TABBAR) MODIFIÉE
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(2), // Réduit de 4 à 2 pour affiner
            height: 45, // Force une hauteur plus petite pour affiner le cercle
            decoration: BoxDecoration(
              color: AppColors.light,
              borderRadius: BorderRadius.circular(25), // Plus arrondi
            ),
            child: TabBar(
              controller: _tabController,
              // Réduit le padding vertical interne des labels pour réduire la hauteur du "bouton"
              labelPadding: const EdgeInsets.symmetric(vertical: 0),
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 2,
                  ),
                ],
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(
                  child: Text(
                    'Nous joindre',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Tab(
                  child: Text(
                    'Un message',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab "Nous joindre" - Informations KKS
                _buildContactInfo(),

                // Tab "Un message" - Le formulaire
                _buildMessageForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NOUVEAU WIDGET : Informations de contact KKS
  Widget _buildContactInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: AppColors.light,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.business,
                size: 40,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Center(
            child: Text(
              "KKS TECHNOLOGIES",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const Center(
            child: Text(
              "Solutions Digitales & Informatiques",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 30),

          // Adresse
          _buildInfoTile(
            icon: Icons.location_on,
            title: "Adresse",
            subtitle: "Mandela, Abidjan, Cocody, Angré",
          ),

          const Divider(height: 20),

          // Téléphone
          _buildInfoTile(
            icon: Icons.phone,
            title: "Téléphone",
            subtitle: "+225 27 22 36 50 27\n+225 07 59 99 01 86",
          ),

          const Divider(height: 20),

          // Email
          _buildInfoTile(
            icon: Icons.email,
            title: "Email",
            subtitle: "contact@kks-technologies.com",
          ),

          const Divider(height: 20),

          // Site Web
          _buildInfoTile(
            icon: Icons.language,
            title: "Site Web",
            subtitle: "https://kks-technologies.com",
            isLink: true,
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.light.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.access_time, size: 20, color: Colors.grey),
                SizedBox(width: 10),
                Text(
                  "Lun - Ven: 09h00 - 18h00",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isLink ? Colors.blue : Colors.black87,
                  decoration: isLink ? TextDecoration.underline : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Formulaire de commentaires",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField("Prénom / Nom de famille", _nameController),
            const SizedBox(height: 12),
            _buildTextField(
              "Email",
              _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              "Téléphone",
              _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildTextField("Commentaire", _messageController, maxLines: 5),

            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  "0/500",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Bouton Historique
            ElevatedButton(
              onPressed: _showHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text("Mon historique de feedback"),
            ),

            const SizedBox(height: 12),

            // Bouton Envoyer
            ElevatedButton(
              onPressed: _isLoading ? null : _submitFeedback,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Envoyer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.light,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 10),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ... La classe FeedbackHistoryScreen reste inchangée ...
class FeedbackHistoryScreen extends StatelessWidget {
  const FeedbackHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Historique', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 1,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: FeedbackService().getMyFeedbacks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erreur: ${snapshot.error}"));
          }
          final feedbacks = snapshot.data ?? [];
          if (feedbacks.isEmpty) {
            return const Center(child: Text("Aucun feedback envoyé"));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: feedbacks.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = feedbacks[index];
              final dateStr = item['created_at'];
              return ListTile(
                onTap: () {
                  // Navigation vers les détails du feedback pour répondre
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => FeedbackDetailScreen(
                        feedbackId: item['id'],
                        initialMessage: item['message'] ?? '',
                        initialDate: dateStr,
                      ),
                    ),
                  );
                },
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item['message'] ?? '...',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(dateStr ?? ''),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item['status'] == 'pending'
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item['status'] ?? 'pending',
                    style: TextStyle(
                      color: item['status'] == 'pending'
                          ? Colors.orange
                          : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
