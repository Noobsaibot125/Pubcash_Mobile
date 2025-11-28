import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/promotion.dart';
import '../../services/promotion_service.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PromotionService _promotionService = PromotionService();
  late Future<List<Promotion>> _promotionsFuture;
  late Future<Map<String, dynamic>> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _promotionsFuture = _promotionService.getUserPromotions();
    _earningsFuture = _promotionService.getEarnings();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/images/logo.png', height: 40),
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          CircleAvatar(
            backgroundImage: user?.photoUrl != null
                ? NetworkImage(user!.photoUrl!)
                : const NetworkImage('https://via.placeholder.com/150'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              FutureBuilder<Map<String, dynamic>>(
                future: _earningsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  } else if (!snapshot.hasData) {
                    return const Center(child: Text('Aucun gain.'));
                  } else {
                    final earnings = snapshot.data!;
                    return Card(
                      color: Colors.orange,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Solde actuel',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            Text(
                              '${earnings['solde_actuel'] ?? 0} FCFA',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.visibility, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(Icons.home, 'Accueil'),
                  _buildActionButton(Icons.diamond, 'Premium'),
                  _buildActionButton(Icons.star, 'Populaire'),
                  _buildActionButton(Icons.card_membership, 'Abonnement'),
                ],
              ),
              const SizedBox(height: 16),
              // Video List
              FutureBuilder<List<Promotion>>(
                future: _promotionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('Aucune vidéo disponible.'));
                  } else {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final promotion = snapshot.data![index];
                        return _buildVideoCard(
                          promotion.thumbnailUrl ?? 'https://via.placeholder.com/500x250.png?text=Video',
                          promotion.titre,
                          promotion.description ?? '',
                          '${promotion.duree}s',
                          '+${promotion.remunerationPack} F',
                          Icons.diamond, // This could be dynamic
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.orange),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  Widget _buildVideoCard(String imageUrl, String title, String description,
      String duration, String reward, IconData rewardIcon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.network(imageUrl),
              ),
              const Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 60),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    duration,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        reward,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Icon(rewardIcon, color: Colors.yellow, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Regarder et gagner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
