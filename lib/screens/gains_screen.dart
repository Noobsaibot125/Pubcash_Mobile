import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/promotion_service.dart';
import '../../utils/colors.dart';
import 'gains/withdraw_amount_screen.dart';

class GainsScreen extends StatefulWidget {
  const GainsScreen({super.key});

  @override
  State<GainsScreen> createState() => _GainsScreenState();
}

class _GainsScreenState extends State<GainsScreen> {
  final PromotionService _promotionService = PromotionService();
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Recharger le profil pour avoir le solde à jour
    await Provider.of<AuthService>(context, listen: false).refreshUserProfile();
    
    // Charger l'historique
    final history = await _promotionService.getWithdrawHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    // Solde affiché : soit depuis User (mis à jour), soit 0
    final double solde = user?.solde ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ORANGE ---
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C42), Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF8C42).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.settings, color: Colors.white),
                      Text("${user?.prenom ?? ''} ${user?.nom ?? 'User'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Solde actuel", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${solde.toInt()} FCFA", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      const Icon(Icons.remove_red_eye, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF6B35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawAmountScreen()));
                    },
                    child: const Text("Retirer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),

            // --- ONGLETS (Décoratifs pour l'instant) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildTabItem(Icons.home, true)),
                  Expanded(child: _buildTabItem(Icons.diamond, false)),
                  Expanded(child: _buildTabItem(Icons.catching_pokemon, false)), // Pierre/Gold
                  Expanded(child: _buildTabItem(Icons.money, false)),
                ],
              ),
            ),
            
            // --- BARRE VERTE ---
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Expanded(child: Center(child: Text("Gains", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                  VerticalDivider(color: Colors.white, width: 1),
                  Expanded(child: Center(child: Text("Retirer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                ],
              ),
            ),

            // --- LISTE HISTORIQUE ---
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 10),
              child: Align(alignment: Alignment.centerLeft, child: Text("Historique", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ),

            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                  ? const Center(child: Text("Aucun historique récent"))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final isWithdraw = item['montant'] != null; // Simplification
                        // Tu devras adapter selon la structure exacte renvoyée par getWithdrawalHistoryForUser
                        // getWithdrawalHistoryForUser renvoie: id, montant, statut, date, operator
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.download, color: Colors.orange), // Icone retrait
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Retrait ${item['operator'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(item['date'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(item['statut'] ?? '', style: TextStyle(
                                      color: item['statut'] == 'traite' ? Colors.green : Colors.orange, 
                                      fontSize: 12, fontWeight: FontWeight.bold
                                    )),
                                  ],
                                ),
                              ),
                              Text("-${item['montant']} F", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.green,
        borderRadius: BorderRadius.circular(5),
        border: isActive ? Border.all(color: Colors.green) : null,
      ),
      child: Icon(icon, color: isActive ? Colors.green : Colors.white),
    );
  }
}