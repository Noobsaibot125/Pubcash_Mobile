import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/promotion_service.dart';
import '../services/video_service.dart';
import '../services/auth_service.dart';
import '../models/promotion.dart';
import '../utils/colors.dart';
import '../widgets/video_card.dart';
import 'video_player_screen.dart';

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
  
  // Filtre par défaut
  String _filter = 'toutes';
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _loadData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      await authService.refreshUserProfile();
      
      // On envoie le filtre actuel à l'API
      final promos = await _promotionService.getPromotions(filter: _filter);
      final earnings = await _promotionService.getEarnings();
      
      if (mounted) {
        setState(() {
          _promotions = promos;
          _earnings = earnings;
          _points = authService.currentUser?.points ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      print("Erreur globale chargement home: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openVideoPlayer(Promotion promo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenVideoScreen(
          promotion: promo,
          onVideoViewed: () {
             _loadData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // === APP BAR ===
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.1),
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('PC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PubCash', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 20)),
                        if (user != null)
                          Text("Bonjour, ${user.nomUtilisateur}", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppColors.textDark),
                    onPressed: () {},
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // === CARTE SOLDE ===
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
                            BoxShadow(color: const Color(0xFFFF8C42).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Solde actuel', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star, color: Colors.white, size: 18),
                                      const SizedBox(width: 6),
                                      Text('$_points pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${_earnings['total'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, height: 1)),
                                const SizedBox(width: 8),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: Text('FCFA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // === FILTRES CIRCULAIRES (CORRIGÉS) ===
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFilterIcon(Icons.home_rounded, 'Tous', 'toutes', const Color(0xFFFF6B35)),
                          
                          // API Filter: 'agent' (Database: Agent, UI: Argent)
                          _buildFilterIcon(Icons.attach_money, 'Argent', 'agent', const Color(0xFFC0C0C0)),
                          
                          // API Filter: 'gold' (Database: Gold)
                          _buildFilterIcon(Icons.workspace_premium, 'Gold', 'gold', const Color(0xFFFFD700)),
                          
                          // API Filter: 'diamant' (Database: Diamant)
                          _buildFilterIcon(Icons.diamond, 'Diamant', 'diamant', const Color(0xFF00BCD4)),
                          
                          // API Filter: 'ma_commune'
                          _buildFilterIcon(Icons.location_on, 'Commune', 'ma_commune', const Color(0xFF9C27B0)),
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
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_promotions.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library_outlined, size: 80, color: AppColors.textMuted),
                        SizedBox(height: 16),
                        Text('Aucune vidéo pour ce filtre', style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
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
                      // On passe juste l'image (thumbnail) au VideoCard
                      // Le clic est géré ici
                      return GestureDetector(
                        onTap: () => _openVideoPlayer(promo),
                        child: VideoCard(
                          promotion: promo,
                          // On désactive la logique interne du VideoCard car on gère tout ici
                          isLiked: false, 
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

  Widget _buildFilterIcon(IconData icon, String label, String filterValue, Color color) {
    final isActive = _filter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = filterValue;
        });
        _loadData(); // Recharger avec le nouveau filtre
      },
      child: Column(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.white,
              shape: BoxShape.circle,
              border: isActive ? null : Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? color : Colors.grey).withOpacity(0.3),
                  blurRadius: isActive ? 10 : 5,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: isActive ? Colors.white : color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? color : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}