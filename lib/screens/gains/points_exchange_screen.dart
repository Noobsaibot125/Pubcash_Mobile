import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/promotion_service.dart';
import '../../utils/colors.dart';

class PointsExchangeScreen extends StatefulWidget {
  const PointsExchangeScreen({super.key});

  @override
  State<PointsExchangeScreen> createState() => _PointsExchangeScreenState();
}

class _PointsExchangeScreenState extends State<PointsExchangeScreen> {
  final PromotionService _promotionService = PromotionService();
  bool _isConverting = false;

  final List<Map<String, dynamic>> _exchangePacks = [
    {'points': 50, 'amount': 200, 'color': Colors.brown, 'name': 'Pack Bronze'},
    {'points': 100, 'amount': 500, 'color': Colors.grey, 'name': 'Pack Silver'},
    {
      'points': 250,
      'amount': 1500,
      'color': Colors.orange,
      'name': 'Pack Gold',
    },
    {
      'points': 500,
      'amount': 3500,
      'color': Colors.cyan,
      'name': 'Pack Diamant',
    },
  ];

  Future<void> _handleConversion(int points, int amount) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if ((authService.currentUser?.points ?? 0) < points) return;

    setState(() => _isConverting = true);

    try {
      await _promotionService.convertPoints(points: points, amount: amount);

      // Rafraîchir le profil pour mettre à jour les points et le solde
      await authService.refreshUserProfile();

      if (mounted) {
        _showSuccessDialog(amount);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erreur: ${e.toString()}")));
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  void _showSuccessDialog(int amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: Colors.orange, size: 80),
            const SizedBox(height: 20),
            const Text(
              "Conversion Réussie !",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Vous avez reçu $amount FCFA sur votre solde.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Génial !",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPoints =
        Provider.of<AuthService>(context).currentUser?.points ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Échange de Points",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // HEADER : Solde de points et FCFA
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D3436), Color(0xFF000000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Solde Principal (FCFA)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Solde principal",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          "${Provider.of<AuthService>(context).currentUser?.solde.toInt() ?? 0} FCFA",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(color: Colors.white12, height: 1),
                    ),
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.orange,
                      size: 45,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Points Accumulés",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    Text(
                      "$userPoints pts",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Choisissez un pack à convertir",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // GRID DE PACKS
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 0.85,
                ),
                itemCount: _exchangePacks.length,
                itemBuilder: (context, index) {
                  final pack = _exchangePacks[index];
                  final bool canAfford = userPoints >= pack['points'];

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: pack['color'].withOpacity(0.1),
                          radius: 25,
                          child: Icon(
                            Icons.card_giftcard,
                            color: pack['color'],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          pack['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "${pack['amount']} FCFA",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Divider(indent: 20, endIndent: 20, height: 20),
                        Text(
                          "${pack['points']} pts requis",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford
                                  ? Colors.orange
                                  : Colors.grey[300],
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: (canAfford && !_isConverting)
                                ? () => _handleConversion(
                                    pack['points'],
                                    pack['amount'],
                                  )
                                : null,
                            child: _isConverting
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    "Échanger",
                                    style: TextStyle(
                                      color: canAfford
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              const Text(
                "Les points s'accumulent en jouant à nos jeux !\nRevenez souvent pour les convertir.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
