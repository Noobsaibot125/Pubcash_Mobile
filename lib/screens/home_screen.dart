import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pub_cash_mobile/screens/quiz_screen.dart';
import '../../models/promotion.dart';
import '../../services/promotion_service.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Services
  final PromotionService _promotionService = PromotionService();

  // Futures for data
  late Future<List<Promotion>> _promotionsFuture;
  late Future<Map<String, dynamic>> _earningsFuture;

  @override
  void initState() {
    super.initState();
    // Initialize data fetching
    _promotionsFuture = _promotionService.getUserPromotions();
    _earningsFuture = _promotionService.getEarnings();
  }

  void _refreshData() {
    setState(() {
      _promotionsFuture = _promotionService.getUserPromotions();
      _earningsFuture = _promotionService.getEarnings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                ? NetworkImage(user.photoUrl!)
                : const AssetImage('assets/images/logo.png') as ImageProvider,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue,',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            Text(
              user?.nomUtilisateur ?? 'Utilisateur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textDark),
            onPressed: () { /* TODO: Notification screen */ },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBalanceCard(),
                const SizedBox(height: 24),
                _buildSectionHeader('Vidéos pour vous'),
                const SizedBox(height: 16),
                _buildVideoList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _earningsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('Erreur: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Text('Aucun solde disponible.');
        }

        final earnings = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Solde Actuel',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${earnings['solde_actuel'] ?? 0} FCFA',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildVideoList() {
    return FutureBuilder<List<Promotion>>(
      future: _promotionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Aucune vidéo disponible pour le moment.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          );
        }

        final promotions = snapshot.data!;
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: promotions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final promotion = promotions[index];
            return _buildVideoCard(promotion);
          },
        );
      },
    );
  }

  Widget _buildVideoCard(Promotion promotion) {
    return GestureDetector(
      onTap: () {
        // TODO: Navigate to video player screen
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                Image.network(
                  promotion.thumbnailUrl ?? 'https://via.placeholder.com/500x250.png?text=PubCash',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.error_outline, color: Colors.grey)),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                         decoration: BoxDecoration(
                           color: AppColors.primary.withOpacity(0.8),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Text(
                           '+${promotion.remunerationPack} FCFA',
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                         ),
                       ),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                         decoration: BoxDecoration(
                           color: Colors.black.withOpacity(0.5),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Text(
                           '${promotion.duree}s',
                           style: const TextStyle(color: Colors.white),
                         ),
                       ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promotion.titre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    promotion.description ?? 'Aucune description',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (promotion.quiz != null)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.quiz_outlined),
                          label: const Text('Commencer le Quiz'),
                          onPressed: () async {
                            final bool? quizSuccess = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuizScreen(promotion: promotion),
                              ),
                            );
                            if (quizSuccess == true) {
                              _refreshData();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.favorite_border, color: AppColors.primary),
                        onPressed: () async {
                          try {
                            await _promotionService.likePromotion(promotion.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vidéo aimée !'), backgroundColor: AppColors.success),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: AppColors.secondary),
                        onPressed: () async {
                          try {
                            await _promotionService.sharePromotion(promotion.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vidéo partagée !'), backgroundColor: AppColors.success),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
