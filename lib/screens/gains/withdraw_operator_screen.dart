import 'package:flutter/material.dart';
import 'package:pubcash_mobile/utils/colors.dart';
import 'withdraw_phone_screen.dart';

class WithdrawOperatorScreen extends StatefulWidget {
  final int amount;
  const WithdrawOperatorScreen({super.key, required this.amount});

  @override
  State<WithdrawOperatorScreen> createState() => _WithdrawOperatorScreenState();
}

class _WithdrawOperatorScreenState extends State<WithdrawOperatorScreen> {
  String? _selectedOperator; // 'orange', 'mtn', 'moov', 'wave'

  final List<Map<String, dynamic>> operators = [
    {'id': 'orange', 'name': 'Orange Money', 'color': const Color(0xFFFFE0B2)}, // Fond Orange clair
    {'id': 'mtn', 'name': 'MTN Money', 'color': const Color(0xFFFFF9C4)},    // Fond Jaune clair
    {'id': 'moov', 'name': 'Moov Money', 'color': const Color(0xFFE1F5FE)},   // Fond Bleu clair
    {'id': 'wave', 'name': 'Wave', 'color': const Color(0xFFE0F7FA)},         // Fond Cyan clair
  ];

  void _goToPhone() {
    if (_selectedOperator == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WithdrawPhoneScreen(
          amount: widget.amount, 
          operatorId: _selectedOperator!,
          operatorName: operators.firstWhere((o) => o['id'] == _selectedOperator)['name'],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mode de retrait"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("Choisissez votre mode de paiement", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
            const SizedBox(height: 30),

            ...operators.map((op) => Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: GestureDetector(
                onTap: () => setState(() => _selectedOperator = op['id']),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: op['color'],
                    borderRadius: BorderRadius.circular(15),
                    border: _selectedOperator == op['id'] ? Border.all(color: Colors.orange, width: 2) : null,
                  ),
                  child: Row(
                    children: [
                      // Placeholder pour logo (Rond coloré pour l'instant)
                      CircleAvatar(backgroundColor: Colors.white, child: Text(op['name'][0])),
                      const SizedBox(width: 15),
                      Text(op['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if (_selectedOperator == op['id'])
                        const Icon(Icons.check_circle, color: Colors.orange)
                      else
                        const Icon(Icons.circle_outlined, color: Colors.grey)
                    ],
                  ),
                ),
              ),
            )).toList(),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _selectedOperator != null ? _goToPhone : null,
                child: const Text("Ajouter", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}