import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour le filtrage chiffres
import '../../services/promotion_service.dart';
import 'withdraw_operator_screen.dart';

class WithdrawAmountScreen extends StatefulWidget {
  final double? currentBalance; // On reçoit le solde de la page précédente
  const WithdrawAmountScreen({super.key, this.currentBalance});

  @override
  State<WithdrawAmountScreen> createState() => _WithdrawAmountScreenState();
}

class _WithdrawAmountScreenState extends State<WithdrawAmountScreen> {
  final TextEditingController _amountController = TextEditingController();
  final PromotionService _promotionService = PromotionService();
  
  double _solde = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Si on a reçu le solde, on l'utilise, sinon on le charge
    if (widget.currentBalance != null) {
      _solde = widget.currentBalance!;
      _isLoading = false;
    } else {
      _fetchBalance();
    }
  }

  Future<void> _fetchBalance() async {
    try {
      final data = await _promotionService.getEarnings();
      if (mounted) {
        setState(() {
          _solde = double.tryParse(data['total'].toString()) ?? 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // Met à jour le champ texte quand on clique sur un bouton rapide
  void _selectAmount(int amount) {
    _amountController.text = amount.toString();
    _amountController.selection = TextSelection.fromPosition(TextPosition(offset: _amountController.text.length));
    setState(() {}); 
  }

  void _goToOperator() {
    // Fermer le clavier
    FocusScope.of(context).unfocus();

    if (_amountController.text.isEmpty) return;
    
    int? amount = int.tryParse(_amountController.text);
    
    if (amount == null || amount < 200) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le montant minimum est de 200 FCFA"), backgroundColor: Colors.orange));
       return;
    }
    
    if (amount > _solde) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solde insuffisant"), backgroundColor: Colors.red));
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawOperatorScreen(amount: amount)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Choisir le montant", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), 
          centerTitle: true, 
          backgroundColor: Colors.white, 
          elevation: 0, 
          iconTheme: const IconThemeData(color: Colors.black)
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 30),
                
                // --- CHAMP DE SAISIE MANUELLE ---
                IntrinsicWidth(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Uniquement des chiffres
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                    decoration: InputDecoration(
                      hintText: "0",
                      hintStyle: TextStyle(color: Colors.orange[200]),
                      border: InputBorder.none,
                      suffixText: " FCFA",
                      suffixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    onChanged: (val) => setState(() {}), 
                  ),
                ),
                
                const SizedBox(height: 10),
                Text(
                  "Solde disponible : ${_solde.toInt()} FCFA", 
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)
                ),
                
                const Divider(height: 60, thickness: 1),
                
                const Text("Montant rapide", style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 20),
    
                // BOUTONS RAPIDES
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  children: [
                    _buildAmountBtn(500),
                    _buildAmountBtn(1000),
                    _buildAmountBtn(2000),
                    _buildAmountBtn(5000),
                  ],
                ),
    
                const SizedBox(height: 50),

                // BOUTON CONTINUER
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    onPressed: _amountController.text.isNotEmpty ? _goToOperator : null,
                    child: const Text("Continuer", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountBtn(int amount) {
    bool isSelected = _amountController.text == amount.toString();
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.orange : const Color(0xFF4CAF50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: () => _selectAmount(amount),
      child: Text("$amount FCFA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}