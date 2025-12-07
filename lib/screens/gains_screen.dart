import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/api_constants.dart'; 
import '../../services/auth_service.dart';
import '../../services/promotion_service.dart';
import '../../utils/colors.dart';
import 'package:pubcash_mobile/screens/gains/withdraw_amount_screen.dart';
import 'simple_video_player.dart'; // ðŸ‘ˆ IMPORT DU LECTEUR
import 'package:pubcash_mobile/screens/gains/transaction_details_screen.dart'; // ðŸ‘ˆ IMPORT DE LA NOUVELLE PAGE

class GainsScreen extends StatefulWidget {
  const GainsScreen({super.key});

  @override
  State<GainsScreen> createState() => _GainsScreenState();
}

class _GainsScreenState extends State<GainsScreen> {
  final PromotionService _promotionService = PromotionService();
  
  List<dynamic> _withdrawHistory = []; 
  List<dynamic> _videoHistory = [];    
  List<dynamic> _filteredVideoHistory = []; 

  double _solde = 0.0;
  bool _isLoading = true;
  
  int _currentTab = 0; 
  String _gainFilter = 'tous'; 

  // IMPORTANT : Assure-toi que c'est la bonne IP ici aussi
  // final String _baseUrl = "http://192.168.1.15:5000"; 

 final String _baseUrl = ApiConstants.socketUrl;
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.refreshUserProfile();

      final earningsData = await _promotionService.getEarnings();
      final withdrawHistory = await _promotionService.getWithdrawHistory();
      
      // On rÃ©cupÃ¨re l'historique complet
      final videoHistoryRaw = await _promotionService.getInteractionHistory();
      
      // On garde les VUES (gains validÃ©s)
      final videoGains = videoHistoryRaw.where((item) => item['type_interaction'] == 'vue').toList();

      if (mounted) {
        setState(() {
          _solde = double.tryParse(earningsData['total'].toString()) ?? 0.0;
          _withdrawHistory = withdrawHistory;
          _videoHistory = videoGains;
          _applyGainFilter(); 
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur chargement gains: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- METHODE POUR JOUER LA VIDEO (Similaire Ã  History) ---
  void _playVideo(Map<String, dynamic> videoData) {
    String? videoUrl = videoData['url_video'];
    String titre = videoData['titre'] ?? 'VidÃ©o Gain';

    if (videoUrl != null && videoUrl.isNotEmpty) {
      // Reconstruction de l'URL si relative
      if (!videoUrl.startsWith('http')) {
         videoUrl = "$_baseUrl/uploads/videos/$videoUrl";
      }

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleVideoPlayer(
            videoUrl: videoUrl!,
            title: titre,
            promotionId: videoData['id_promotion'] ?? videoData['id'],
            
            // --- CORRECTION ICI ---
            // On récupère l'ID du client (promoteur) pour le bouton Suivre
            clientId: videoData['id_client'] ?? videoData['client_id'] ?? videoData['promoter_id'],
            
            // On récupère le nom
            clientName: videoData['nom_promoteur'] ?? videoData['nom_entreprise'] ?? titre,
            
            // On récupère l'avatar
            clientAvatar: videoData['photo_promoteur'] ?? videoData['profile_image_url'],
            // ---------------------
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("VidÃ©o indisponible (trop ancienne ou supprimÃ©e)")),
      );
    }
  }

  void _applyGainFilter() {
    if (_gainFilter == 'tous') {
      _filteredVideoHistory = List.from(_videoHistory);
    } else {
      _filteredVideoHistory = _videoHistory.where((video) {
        int packId = video['id_pack'] is int ? video['id_pack'] : int.tryParse(video['id_pack'].toString()) ?? 0;
        
        if (_gainFilter == 'argent') return packId == 1; 
        if (_gainFilter == 'gold') return packId == 2;   
        if (_gainFilter == 'diamant') return packId == 3;
        return false;
      }).toList();
    }
  }

  int _getAmountForPack(dynamic packId) {
    int id = packId is int ? packId : int.tryParse(packId.toString()) ?? 0;
    switch (id) {
      case 1: return 50;
      case 2: return 75;
      case 3: return 100;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context); 
    final user = authService.currentUser;
    
    final String displayName = (user?.prenom != null && user!.prenom!.isNotEmpty) 
        ? "${user.prenom} ${user.nom ?? ''}" 
        : (user?.nomUtilisateur ?? 'Utilisateur');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: Column(
            children: [
              // --- HEADER CARTE ORANGE (InchangÃ©) ---
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8C42), Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF8C42).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                        ),
                        Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white24,
                          backgroundImage: (user?.photoUrl != null) 
                            ? NetworkImage(user!.photoUrl!.startsWith('http') 
                                ? user.photoUrl! 
                                : "$_baseUrl/uploads/profile/${user.photoUrl}") 
                            : null,
                          child: user?.photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text("Solde actuel", style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // AJOUT DE FLEXIBLE et FITTEDBOX pour éviter l'erreur de dépassement
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              authService.showBalance 
                                  ? "${_solde.toInt()} FCFA" 
                                  : "••••••", // On met des points simples ici
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 32, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => authService.toggleBalance(),
                          child: Icon(
                            authService.showBalance ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white70,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFF6B35),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        onPressed: () {
                           Navigator.push(
                             context, 
                             MaterialPageRoute(builder: (_) => WithdrawAmountScreen(currentBalance: _solde))
                           );
                        },
                        child: const Text("Faire un retrait", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),

              // --- BARRE D'ONGLETS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Container(
                  height: 55,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton("Gains", Icons.monetization_on, 0),
                      _buildTabButton("Transactions", Icons.history, 1),
                    ],
                  ),
                ),
              ),

              // --- CONTENU PRINCIPAL ---
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _currentTab == 0 
                      ? _buildGainsView()       
                      : _buildTransactionsView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, IconData icon, int index) {
    final bool isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isActive 
              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isActive ? Colors.green : Colors.grey[500], size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isActive ? Colors.black87 : Colors.grey[500], fontSize: 14, fontWeight: isActive ? FontWeight.bold : FontWeight.w500))
            ],
          ),
        ),
      ),
    );
  }

  // --- VUE GAINS (AVEC CLIC ACTIVÃ‰) ---
  Widget _buildGainsView() {
    return Column(
      children: [
        // Filtres
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFilterIcon(Icons.grid_view_rounded, 'Tous', 'tous', const Color(0xFFFF6B35)),
              _buildFilterIcon(Icons.attach_money, 'Argent', 'argent', const Color(0xFFC0C0C0)), 
              _buildFilterIcon(Icons.workspace_premium, 'Gold', 'gold', const Color(0xFFFFD700)), 
              _buildFilterIcon(Icons.diamond, 'Diamant', 'diamant', const Color(0xFF00BCD4)), 
            ],
          ),
        ),

        const SizedBox(height: 5),

        Expanded(
          child: _filteredVideoHistory.isEmpty
            ? _buildEmptyState("Aucun gain trouvÃ© pour ce filtre.")
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _filteredVideoHistory.length,
                itemBuilder: (context, index) {
                  final item = _filteredVideoHistory[index];
                  final amount = _getAmountForPack(item['id_pack']);
                  final dateStr = item['date_creation'] ?? item['date_interaction'];
                  final dateDisplay = dateStr != null ? dateStr.toString().substring(0, 10) : '';

                  // ðŸ‘‡ C'EST ICI LE CLIC POUR LA VIDÃ‰O
                  return GestureDetector(
                    onTap: () => _playVideo(item), // Lance la vidÃ©o au clic
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 45, height: 45,
                            decoration: BoxDecoration(
                              color: _getPackColor(item['id_pack']).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            // Petite icÃ´ne Play pour montrer que c'est cliquable
                            child: Icon(Icons.play_arrow, color: _getPackColor(item['id_pack'])),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['titre'] ?? 'Promotion', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text("RegardÃ© le $dateDisplay", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("+ $amount F", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("ValidÃ©", style: TextStyle(color: Colors.green[700], fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildFilterIcon(IconData icon, String label, String value, Color color) {
    final bool isSelected = _gainFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _gainFilter = value;
          _applyGainFilter();
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              shape: BoxShape.circle,
              border: isSelected ? null : Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? color : Colors.grey).withOpacity(0.25),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: isSelected ? Colors.white : color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? color : Colors.grey[500])),
        ],
      ),
    );
  }

 Widget _buildTransactionsView() {
    if (_withdrawHistory.isEmpty) return _buildEmptyState("Aucune transaction effectuÃ©e.");

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: _withdrawHistory.length,
      itemBuilder: (context, index) {
        final item = _withdrawHistory[index];
        
        String statusText = item['statut'] ?? 'En attente';
        Color statusColor = Colors.orange;
        IconData statusIcon = Icons.access_time;
        
        if (statusText == 'traite' || statusText == 'succes') {
          statusText = "SuccÃ¨s";
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
        } else if (statusText == 'rejete' || statusText == 'echec') {
          statusText = "Ã‰chouÃ©";
          statusColor = Colors.red;
          statusIcon = Icons.cancel;
        }

        // ðŸ‘‡ C'EST ICI LE CHANGEMENT : GESTURE DETECTOR
        return GestureDetector(
          onTap: () {
            // Navigation vers l'Ã©cran de dÃ©tail
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransactionDetailsScreen(transaction: item),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(16), 
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.outbond, color: statusColor, size: 22),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Retrait ${item['operator'] ?? 'Mobile'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(item['date'] != null ? item['date'].toString().substring(0, 10) : 'Date inconnue', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("-${item['montant']} F", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  Color _getPackColor(dynamic packId) {
    int id = packId is int ? packId : int.tryParse(packId.toString()) ?? 0;
    switch (id) {
      case 1: return Colors.grey;
      case 2: return const Color(0xFFFFD700);
      case 3: return Colors.cyan;
      default: return AppColors.primary;
    }
  }
}