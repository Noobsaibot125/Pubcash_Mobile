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
  String? _selectedOperator;

  // Liste avec les chemins d'images corrects
  final List<Map<String, dynamic>> operators = [
    {
      'id': 'orange',
      'name': 'Orange Money',
      'color': const Color(0xFFFFE0B2),
      'image': 'assets/images/Orange.png',
    },
    {
      'id': 'mtn',
      'name': 'MTN Money',
      'color': const Color(0xFFFFF9C4),
      'image': 'assets/images/MTN.png',
    },
    {
      'id': 'moov',
      'name': 'Moov Money',
      'color': const Color(0xFFE1F5FE),
      'image': 'assets/images/Moov.png',
    },
    {
      'id': 'wave',
      'name': 'Wave',
      'color': const Color(0xFFE0F7FA),
      'image': 'assets/images/Wave.png',
    },
  ];

  void _goToPhone() {
    if (_selectedOperator == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WithdrawPhoneScreen(
          amount: widget.amount,
          operatorId: _selectedOperator!,
          operatorName: operators.firstWhere(
            (o) => o['id'] == _selectedOperator,
          )['name'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Mode de retrait",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "Choisissez votre mode de paiement",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ...operators
                  .map(
                    (op) => Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedOperator = op['id']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: op['color'],
                            borderRadius: BorderRadius.circular(15),
                            border: _selectedOperator == op['id']
                                ? Border.all(color: Colors.orange, width: 2)
                                : Border.all(color: Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              // Affichage du Logo (Image)
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: AssetImage(op['image']),
                                    fit: BoxFit
                                        .cover, // ou BoxFit.contain selon l'image
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),

                              Text(
                                op['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const Spacer(),

                              // Checkbox personnalisé
                              if (_selectedOperator == op['id'])
                                const Icon(
                                  Icons.radio_button_checked,
                                  color: Colors.orange,
                                )
                              else
                                const Icon(
                                  Icons.radio_button_unchecked,
                                  color: Colors.grey,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  onPressed: _selectedOperator != null ? _goToPhone : null,
                  child: const Text(
                    "Ajouter",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
