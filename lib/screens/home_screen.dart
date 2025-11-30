import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/promotion_service.dart';
import '../services/video_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/promotion.dart';
import '../utils/colors.dart';
import '../widgets/video_card.dart';
import 'video_player_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PromotionService _promotionService = PromotionService();
  // ignore: unused_field
  final VideoService _videoService = VideoService();

  List<Promotion> _promotions = [];
  Map<String, dynamic> _earnings = {'total': 0};
  int _points = 0;
  
  // Variable pour le badge de notification
  int _unreadCount = 0;
  StreamSubscription<int>? _badgeSubscription; // Pour écouter les notifs en temps réel
  
  bool _loading = true;
  
  // Filtre par défaut
  String _filter = 'toutes';
  bool _isInit = true;

  // Pour cacher/montrer le solde
  bool _showBalance = true;

  @override
  void initState() {
    super.initState();
    // On s'abonne au flux de notifications dès le lancement
    _badgeSubscription = NotificationService().unreadCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _loadData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // Très important : on coupe l'écoute quand on quitte l'écran
    _badgeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      // 1. Charger profil user
      await authService.refreshUserProfile();
      
      // 2. Charger les données API en parallèle
      // Note: getUnreadCount va aussi déclencher le Stream, donc _unreadCount se mettra à jour
      final results = await Future.wait([
        _promotionService.getPromotions(filter: _filter),
        _promotionService.getEarnings(),
        NotificationService().getUnreadCount() 
      ]);

      final promos = results[0] as List<Promotion>;
      final earnings = results[1] as Map<String, dynamic>;
      // results[2] est le count, mais le stream le gère aussi. On le prend quand même.
      final unread = results[2] as int;
      
      if (mounted) {
        setState(() {
          _promotions = promos;
          _earnings = earnings;
          _points = authService.currentUser?.points ?? 0;
          _unreadCount = unread;
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

  String? _getProfileImageUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('http')) {
      return "$photoUrl?v=${DateTime.now().millisecondsSinceEpoch}";
    }
    const String baseUrl = "http://192.168.1.15:5000"; 
    return "$baseUrl/uploads/profile/$photoUrl?v=${DateTime.now().millisecondsSinceEpoch}";
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final photoUrl = _getProfileImageUrl(user?.photoUrl);

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
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40, 
                      width: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.grey),
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
                  // --- NOTIFICATIONS ---
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: AppColors.textDark),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                          ).then((_) => _loadData());
                        },
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$_unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // --- PROFIL UTILISATEUR ---
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ProfileScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 15.0, left: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null 
                              ? const Icon(Icons.person, color: Colors.grey, size: 20) 
                              : null,
                        ),
                      ),
                    ),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _showBalance ? '${_earnings['total'] ?? 0}' : '••••',
                                      style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, height: 1),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_showBalance)
                                      const Text('FCFA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showBalance = !_showBalance;
                                    });
                                  },
                                  icon: Icon(
                                    _showBalance ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 28,
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
                          _buildFilterIcon(Icons.home_rounded, 'Tous', 'toutes', const Color(0xFFFF6B35)),
                          _buildFilterIcon(Icons.attach_money, 'Argent', 'argent', const Color(0xFFC0C0C0)),
                          _buildFilterIcon(Icons.workspace_premium, 'Gold', 'gold', const Color(0xFFFFD700)),
                          _buildFilterIcon(Icons.diamond, 'Diamant', 'diamant', const Color(0xFF00BCD4)),
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
                      return GestureDetector(
                        onTap: () => _openVideoPlayer(promo),
                        child: VideoCard(
                          promotion: promo,
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