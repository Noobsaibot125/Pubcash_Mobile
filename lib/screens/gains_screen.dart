import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/promotion_service.dart';
import '../../utils/colors.dart';
import 'package:pubcash_mobile/screens/gains/withdraw_amount_screen.dart';

class GainsScreen extends StatefulWidget {
  const GainsScreen({super.key});

  @override
  State<GainsScreen> createState() => _GainsScreenState();
}

class _GainsScreenState extends State<GainsScreen> {
  final PromotionService _promotionService = PromotionService();
  
  List<dynamic> _history = [];
  double _solde = 0.0; // On stocke le solde ici localement
  bool _isLoading = true;
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. On récupère les gains comme sur la Home (C'est la méthode qui marche)
      final earningsData = await _promotionService.getEarnings();
      
      // 2. On récupère l'historique
      final history = await _promotionService.getWithdrawHistory();
      
      if (mounted) {
        setState(() {
          // Conversion sécurisée du solde
          _solde = double.tryParse(earningsData['total'].toString()) ?? 0.0;
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur chargement gains: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final String displayName = (user?.prenom != null && user!.prenom!.isNotEmpty) 
        ? "${user.prenom} ${user.nom ?? ''}" 
        : (user?.nomUtilisateur ?? 'Utilisateur');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: Column(
            children: [
              // --- HEADER CARTE ORANGE ---
              Container(
                margin: const EdgeInsets.all(16),
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
                          backgroundImage: NetworkImage(user?.photoUrl ?? 'https://via.placeholder.com/150'),
                          backgroundColor: Colors.white24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text("Solde actuel", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    
                    // --- SOLDE + OEIL ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isBalanceVisible ? "${_solde.toInt()} FCFA" : "••••••",
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                          child: Icon(
                            _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.white70,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    // Bouton Retirer Blanc
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFF6B35),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        onPressed: () {
                           // On passe le solde à l'écran suivant pour éviter de recharger
                           Navigator.push(
                             context, 
                             MaterialPageRoute(builder: (_) => WithdrawAmountScreen(currentBalance: _solde))
                           );
                        },
                        child: const Text("Retirer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                    ),
                  ],
                ),
              ),

              // --- BARRE D'ONGLETS ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      // Onglet Actif (Maison/Gains)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1), 
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.monetization_on, color: Colors.green),
                              Text("Gains", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))
                            ],
                          ),
                        ),
                      ),
                      // Séparateur
                      Container(width: 1, height: 30, color: Colors.grey[200]),
                      // Onglet Passif (Retrait rapide)
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawAmountScreen(currentBalance: _solde))),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.outbond, color: Colors.grey[400]),
                              Text("Retirer", style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold))
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- TITRE HISTORIQUE ---
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
                child: Align(alignment: Alignment.centerLeft, child: Text("Historique des transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark))),
              ),

              // --- LISTE HISTORIQUE ---
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _history.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text("Aucun historique récent", style: TextStyle(color: Colors.grey[400])),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          final item = _history[index];
                          
                          // Gestion des statuts et couleurs
                          String statusText = item['statut'] ?? 'En attente';
                          Color statusColor = Colors.orange;
                          IconData statusIcon = Icons.access_time;
                          
                          if (statusText == 'traite') {
                            statusText = "Succès";
                            statusColor = Colors.green;
                            statusIcon = Icons.check_circle;
                          } else if (statusText == 'rejete') {
                            statusText = "Échoué";
                            statusColor = Colors.red;
                            statusIcon = Icons.cancel;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white, 
                              borderRadius: BorderRadius.circular(16), 
                              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.account_balance, color: statusColor, size: 22),
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
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildTabItem(IconData icon, bool isActive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: isActive ? Colors.white : Colors.grey[400], size: 24),
      ),
    );
  }
}
