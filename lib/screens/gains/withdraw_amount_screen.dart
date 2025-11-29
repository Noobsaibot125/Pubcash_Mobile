import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/colors.dart';
import 'withdraw_operator_screen.dart';

class WithdrawAmountScreen extends StatefulWidget {
  const WithdrawAmountScreen({super.key});

  @override
  State<WithdrawAmountScreen> createState() => _WithdrawAmountScreenState();
}

class _WithdrawAmountScreenState extends State<WithdrawAmountScreen> {
  int? _selectedAmount;

  void _selectAmount(int amount) {
    setState(() => _selectedAmount = amount);
  }

  void _goToOperator() {
    if (_selectedAmount == null) return;
    
    // Vérification solde
    final solde = Provider.of<AuthService>(context, listen: false).currentUser?.solde ?? 0;
    if (_selectedAmount! > solde) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solde insuffisant"), backgroundColor: Colors.red));
      return;
    }

    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => WithdrawOperatorScreen(amount: _selectedAmount!))
    );
  }

  @override
  Widget build(BuildContext context) {
    final solde = Provider.of<AuthService>(context).currentUser?.solde ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Choisir le montant"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text("0 FCFA", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.orange[800])),
            const SizedBox(height: 10),
            Text("Solde disponible : ${solde.toInt()} FCFA", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 40, thickness: 1),
            
            const Text("Montant rapide", style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 20),

            // GRILLE DE BOUTONS
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              children: [
                _buildAmountBtn(500),
                _buildAmountBtn(1000),
                _buildAmountBtn(2000),
                _buildAmountBtn(5000),
              ],
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _selectedAmount != null ? _goToOperator : null,
                child: const Text("Continuer", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountBtn(int amount) {
    bool isSelected = _selectedAmount == amount;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.orange : Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => _selectAmount(amount),
      child: Text("$amount FCFA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}