import 'package:flutter/material.dart';
import '../services/promotion_service.dart';
import '../services/video_service.dart';
import '../models/promotion.dart';
import 'video_player_screen.dart';
import '../utils/colors.dart';
import '../widgets/video_card.dart';
import '../widgets/quiz_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PromotionService _promotionService = PromotionService();
  final VideoService _videoService = VideoService();

  List<Promotion> _promotions = [];
  Map<String, dynamic> _earnings = {'total': 0};
  int _points = 0;
  bool _loading = true;
  String _filter = 'toutes';

  // État des interactions par vidéo
  final Map<int, bool> _likedVideos = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await Future.wait([_loadPromotions(), _loadEarnings(), _loadPoints()]);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadPromotions() async {
    try {
      final promotions = await _promotionService.getPromotions(filter: _filter);
      setState(() {
        _promotions = promotions;
      });
    } catch (e) {
      print('Erreur chargement promotions: $e');
    }
  }

  Future<void> _loadEarnings() async {
    try {
      final earnings = await _promotionService.getEarnings();
      setState(() {
        _earnings = earnings;
      });
    } catch (e) {
      print('Erreur chargement gains: $e');
    }
  }

  Future<void> _loadPoints() async {
    try {
      final points = await _videoService.getPoints();
      setState(() {
        _points = points;
      });
    } catch (e) {
      print('Erreur chargement points: $e');
    }
  }

  void _handleVideoLiked(int promoId) {
    setState(() {
      _likedVideos[promoId] = true;
    });
    _loadEarnings(); // Refresh gains
  }

  void _handleVideoShared(int promoId) {
    // Vérifier s'il y a un quiz
    final promo = _promotions.firstWhere((p) => p.id == promoId);
    if (promo.gameId != null && promo.question != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => QuizModal(
          promotion: promo,
          onCompleted: () {
            _loadPoints(); // Refresh points après le quiz
          },
        ),
      );
    }

    // Refresh et recharger les promotions
    _loadPromotions();
  }
void _openVideoPlayer(Promotion promo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenVideoScreen(
          promotion: promo,
          onVideoViewed: () => _handleVideoViewed(promo.id),
        ),
      ),
    );
  }
  void _handleVideoViewed(int promoId) {
    // Retirer la vidéo de la liste
    setState(() {
      _promotions.removeWhere((p) => p.id == promoId);
    });
    _loadEarnings(); // Refresh gains
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // === APP BAR PERSONNALISÉ ===
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.1),
                title: Row(
                  children: [
                    // Logo
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'PC',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'PubCash',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                actions: [
                  // Bouton notifications
                  IconButton(
                    icon: Stack(
                      children: [
                        const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.textDark,
                          size: 28,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {},
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // === CARTE SOLDE ORANGE 3D ===
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF8C42), Color(0xFFFF6B35)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8C42).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Solde actuel',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$_points pts',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_earnings['total'] ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    'FCFA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.visibility_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // === FILTRES CIRCULAIRES ===
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFilterIcon(
                            Icons.home_rounded,
                            'Tous',
                            'toutes',
                            const Color(0xFFFF6B35),
                          ),
                          _buildFilterIcon(
                            Icons.attach_money,
                            'Argent',
                            'argent',
                            const Color(0xFFC0C0C0),
                          ),
                          _buildFilterIcon(
                            Icons.workspace_premium,
                            'Gold',
                            'gold',
                            const Color(0xFFFFD700),
                          ),
                          _buildFilterIcon(
                            Icons.diamond,
                            'Diamant',
                            'diamant',
                            const Color(0xFF00BCD4),
                          ),
                          _buildFilterIcon(
                            Icons.location_on,
                            'Commune',
                            'ma_commune',
                            const Color(0xFF9C27B0),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // === LISTE DES VIDÉOS ===
              if (_loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_promotions.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: 80,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucune vidéo disponible',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Revenez plus tard !',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 20),
                  sliver: SliverList(
    delegate: SliverChildBuilderDelegate((context, index) {
      final promo = _promotions[index];
      return GestureDetector(
        onTap: () => _openVideoPlayer(promo), // <--- C'est ici qu'on lance le full screen
        child: VideoCard(
          promotion: promo,
          // Désactive les boutons sur la carte pour forcer le clic global
          isLiked: _likedVideos[promo.id] ?? false,
          onLiked: () {}, 
          onShared: () {},
          onViewed: () {},
        ),
      );
    }, childCount: _promotions.length),
  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterIcon(
    IconData icon,
    String label,
    String filterValue,
    Color color,
  ) {
    final isActive = _filter == filterValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = filterValue;
        });
        _loadPromotions();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isActive ? color : Colors.grey).withOpacity(0.3),
                  blurRadius: isActive ? 12 : 8,
                  offset: Offset(0, isActive ? 6 : 4),
                ),
              ],
            ),
            child: Icon(icon, color: isActive ? Colors.white : color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? color : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
