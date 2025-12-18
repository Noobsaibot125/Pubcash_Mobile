import 'dart:async';
import '../utils/api_constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/promotion_service.dart';
import '../services/video_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/promotion.dart';
import '../utils/colors.dart';
import '../services/socket_service.dart';
import '../widgets/video_card.dart';
import 'video_player_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'gains/points_exchange_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? goToProfile;
  final Function(int)? onVideoCountChanged;
  const HomeScreen({
    Key? key,
    this.goToProfile,
    this.onVideoCountChanged, // 👈 Ajout au constructeur
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final PromotionService _promotionService = PromotionService();
  // ignore: unused_field
  final VideoService _videoService = VideoService();

  List<Promotion> _promotions = [];
  Map<String, dynamic> _earnings = {'total': 0};
  int _points = 0;

  // Variable pour le badge de notification
  int _unreadCount = 0;
  StreamSubscription<int>?
  _badgeSubscription; // Pour écouter les notifs en temps réel
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  bool _loading = true;

  // Filtre par défaut
  String _filter = 'toutes';
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // On s'abonne au flux de notifications dès le lancement
    _badgeSubscription = NotificationService().unreadCountStream.listen((
      count,
    ) {
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    });

    // ============================================================
    // SOCKET.IO : Connexion et écoute des nouvelles vidéos en temps réel
    // ============================================================
    SocketService().connect();

    _socketSubscription = SocketService().newVideoStream.listen((videoData) {
      if (!mounted) return;
      if (_shouldShowVideo(videoData)) {
        try {
          final newPromotion = Promotion.fromJson(videoData);
          setState(() {
            _promotions.insert(0, newPromotion);
          });
          // 👇 MISE A JOUR DU COMPTEUR TEMPS RÉEL
          widget.onVideoCountChanged?.call(_promotions.length);
        } catch (e) {
          print(e);
        }
      }
    });

    // ============================================================

    // ============================================================
    // 2. AJOUT CAPITAL : C'EST ICI QU'ON ENVOIE LE TOKEN A LA BDD
    // ============================================================
    // On lance l'initialisation après un court délai pour être sûr
    // que le widget est monté et l'utilisateur connecté.
    Future.delayed(Duration.zero, () async {
      await NotificationService().initialiser();
    });
    // ============================================================
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
    // 2. Remove the observer
    WidgetsBinding.instance.removeObserver(this);

    _badgeSubscription?.cancel();
    _socketSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print(
        "📲 Application reprise (foreground). Vérification du statut du compte...",
      );
      // When app comes to foreground, force a profile refresh.
      // If the account is blocked, refreshUserProfile (in AuthService) will catch the 403 and logout.
      final authService = Provider.of<AuthService>(context, listen: false);
      authService.refreshUserProfile();

      // Optionally refresh other data too
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      // 1. On force la mise à jour du profil (où se trouve le solde utilisateur global)
      await authService.refreshUserProfile();

      // 2. On récupère les gains détaillés
      final earnings = await _promotionService.getEarnings();

      // 3. On récupère les notifs
      final unread = await NotificationService().getUnreadCount();

      // 4. On récupère la liste des vidéos
      final promos = await _promotionService.getPromotions(filter: _filter);

      if (mounted) {
        setState(() {
          _promotions = promos;
          _earnings = earnings;
          // On s'assure de prendre les points frais
          _points = authService.currentUser?.points ?? 0;
          _unreadCount = unread;
          _loading = false;
        });
        widget.onVideoCountChanged?.call(_promotions.length);
      }
    } catch (e) {
      print("Erreur reload home: $e");
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
            // Optimistic UI : Suppression visuelle immédiate (très important pour le cas de la fraude)
            if (mounted) {
              setState(() {
                _promotions.removeWhere((p) => p.id == promo.id);
                // Mise à jour du compteur pour les autres écrans si nécessaire
                widget.onVideoCountChanged?.call(_promotions.length);
              });
            }
          },
        ),
      ),
    ).then((result) async {
      // --- MODIFICATION ICI : Gestion du retour ---

      // Si result == true, cela signifie qu'une action importante a eu lieu (vue validée OU fraude détectée/annulée)
      if (result == true) {
        print("✅ Vidéo traitée (Validée ou Annulée), rechargement...");

        // On force la mise à jour du badge notification
        NotificationService().refreshUnreadCount();

        // ⚠️ CRITIQUE : On attend un peu plus longtemps (1 seconde) avant de recharger les données serveur.
        // Cela laisse le temps à l'API "cancelPromotion" (cas fraude) de bien finir son travail en BDD.
        // Sinon, le serveur risque de renvoyer la vidéo qu'on vient de supprimer localement.
        await Future.delayed(const Duration(milliseconds: 1000));
      } else {
        // Si retour normal (fermeture croix), on recharge vite fait
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Dans tous les cas, on recharge les données pour avoir le Solde à jour
      if (mounted) _loadData();
    });
  }

  String? _getProfileImageUrl(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    // Si le backend fait bien son travail, photoUrl est déjà complet (http...)
    // Mais par sécurité, on garde une petite vérif
    if (photoUrl.startsWith('http')) {
      return photoUrl;
    }
    // Fallback au cas où le backend renverrait encore un nom de fichier brut
    final String baseUrl = ApiConstants.socketUrl;
    return "$baseUrl/uploads/profile/$photoUrl";
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
                toolbarHeight: 80,
                floating: true,
                backgroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.black.withOpacity(0.05),

                centerTitle: false,
                // 👇 ASTUCE ICI : On réduit la marge gauche (était à 20)
                // Cela permet au logo de grandir vers la gauche sans pousser le texte à droite
                titleSpacing: 5,

                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 👇 1. LOGO BIEN GRAND
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8.0,
                      ), // Petite marge interne
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 55, // Agrandit à 55 (au lieu de 40)
                        width: 55,
                        fit: BoxFit.contain,
                        errorBuilder: (c, o, s) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 👇 2. TEXTE (AVEC BONJOUR)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'PubCash',
                          style: TextStyle(
                            color: AppColors.textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 20, // Taille équilibrée
                            height: 1.0,
                          ),
                        ),
                        if (user != null)
                          Text(
                            "Bonjour, ${user.nomUtilisateur}",
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
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
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.black87,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          ).then((_) => _loadData());
                        },
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B35),
                              shape: BoxShape.circle,
                              border: Border.fromBorderSide(
                                BorderSide(color: Colors.white, width: 1.5),
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '$_unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // --- PROFIL UTILISATEUR ---
                  GestureDetector(
                    onTap: () {
                      if (widget.goToProfile != null) {
                        widget.goToProfile!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 15.0, left: 5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 24,
                                )
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
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PointsExchangeScreen(),
                                      ),
                                    ).then(
                                      (_) => _loadData(),
                                    ); // Recharger après l'échange
                                  },
                                  child: Container(
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
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      // MODIFICATION ICI : On utilise authService.showBalance
                                      authService.showBalance
                                          ? '${_earnings['total'] ?? 0}'
                                          : '••••',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // MODIFICATION ICI
                                    if (authService.showBalance)
                                      const Text(
                                        'FCFA',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {
                                    // MODIFICATION ICI : On appelle la méthode globale
                                    authService.toggleBalance();
                                  },
                                  icon: Icon(
                                    // MODIFICATION ICI
                                    authService.showBalance
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
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
                          'Aucune vidéo pour ce filtre',
                          style: TextStyle(
                            fontSize: 18,
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

  bool _shouldShowVideo(Map<String, dynamic> videoData) {
    final ciblageCommune = videoData['ciblage_commune'] as String?;

    // Récupérer la commune de l'utilisateur
    final authService = Provider.of<AuthService>(context, listen: false);
    final userCommune = authService.currentUser?.commune;

    switch (_filter) {
      case 'toutes':
        // Afficher TOUT : vidéos nationales + vidéos de ma commune
        return ciblageCommune == 'toutes' || ciblageCommune == userCommune;

      case 'ma_commune':
        // Afficher uniquement les vidéos qui ciblent MA commune
        return ciblageCommune == userCommune;

      case 'toutes_communes':
        // Afficher uniquement les vidéos nationales
        return ciblageCommune == 'toutes';

      default:
        return true; // Par défaut, afficher
    }
  }
}
