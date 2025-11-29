import 'package:flutter/material.dart';
import '../../services/promotion_service.dart';
import 'package:provider/provider.dart'; // Si besoin pour AuthService
import '../../services/auth_service.dart'; // Si besoin pour rafraichir le solde

class WithdrawVerifyScreen extends StatefulWidget {
  final int amount;
  final String operatorId;
  final String operatorName;
  final String phoneNumber;

  const WithdrawVerifyScreen({
    super.key,
    required this.amount,
    required this.operatorId,
    required this.operatorName,
    required this.phoneNumber,
  });

  @override
  State<WithdrawVerifyScreen> createState() => _WithdrawVerifyScreenState();
}

class _WithdrawVerifyScreenState extends State<WithdrawVerifyScreen> {
  final PromotionService _promotionService = PromotionService();
  bool _isLoading = false;

  Future<void> _processWithdraw() async {
    setState(() => _isLoading = true);

    try {
      await _promotionService.requestWithdraw(
        amount: widget.amount,
        operator: widget.operatorId,
        phoneNumber: widget.phoneNumber,
      );

      if (mounted) {
        // Succès ! On peut rafraichir le solde utilisateur
        await Provider.of<AuthService>(context, listen: false).refreshUserProfile();

        // Afficher dialog de succès
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 20),
                const Text("Retrait Initié !", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Votre demande a été envoyée. Vous recevrez une notification une fois traitée.", textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Close dialog
                    Navigator.of(context).popUntil((route) => route.isFirst); // Retour Accueil
                  },
                  child: const Text("OK"),
                )
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vérification"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // GROS ROND VERT AVEC CHECK
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: Colors.green[100], shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.green, size: 50),
            ),
            const SizedBox(height: 20),
            const Text("Vérifiez les détails", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("Confirmez les informations avant de procéder", style: TextStyle(color: Colors.grey)),
            
            const SizedBox(height: 40),

            // CARD DETAILS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _buildDetailRow("Numéro :", widget.phoneNumber),
                  const Divider(),
                  _buildDetailRow("Montant :", "${widget.amount} FCFA"),
                  const Divider(),
                  _buildDetailRow("Mode de retrait :", widget.operatorName),
                ],
              ),
            ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annuler", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _isLoading ? null : _processWithdraw,
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text("Continuer", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 5),
              const Icon(Icons.edit, size: 16, color: Colors.green)
            ],
          )
        ],
      ),
    );
  }
}