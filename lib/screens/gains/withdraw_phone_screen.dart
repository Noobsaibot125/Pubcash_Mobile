import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'withdraw_verify_screen.dart';

class WithdrawPhoneScreen extends StatefulWidget {
  final int amount;
  final String operatorId;
  final String operatorName;

  const WithdrawPhoneScreen({
    super.key,
    required this.amount,
    required this.operatorId,
    required this.operatorName,
  });

  @override
  State<WithdrawPhoneScreen> createState() => _WithdrawPhoneScreenState();
}

class _WithdrawPhoneScreenState extends State<WithdrawPhoneScreen> {
  final _phoneController = TextEditingController();
  bool _useMyNumber = false;

  void _toggleUseMyNumber(bool? value) {
    setState(() {
      _useMyNumber = value ?? false;
      if (_useMyNumber) {
        // Récupérer le numéro du profil
        final user = Provider.of<AuthService>(
          context,
          listen: false,
        ).currentUser;
        if (user?.contact != null) {
          _phoneController.text = user!.contact!;
        }
      } else {
        _phoneController.clear();
      }
    });
  }

  void _goToVerify() {
    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Numéro invalide (10 chiffres)")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WithdrawVerifyScreen(
          amount: widget.amount,
          operatorId: widget.operatorId,
          operatorName: widget.operatorName,
          phoneNumber: _phoneController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bénéficiaire"), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Augmenté de 20 à 24
          child: Column(
            children: [
              const Text(
                "Choisissez le numéro de destinataire",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // Option 1: Saisir (visuel) ou Utiliser mon numéro
              GestureDetector(
                onTap: () => _toggleUseMyNumber(!_useMyNumber),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(15),
                    color: Colors.orange.withOpacity(0.05),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.orange, size: 30),
                      const SizedBox(width: 15),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Utiliser mon numéro",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Celui de mon profil",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Radio(
                        value: true,
                        groupValue: _useMyNumber,
                        onChanged: _toggleUseMyNumber,
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Champ de saisie
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Entrez le numéro",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        prefixText: "+225 ",
                        prefixStyle: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: "00 00 00 00 00",
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        if (_useMyNumber) setState(() => _useMyNumber = false);
                      },
                    ),
                  ],
                ),
              ),

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
                  ),
                  onPressed: _goToVerify,
                  child: const Text(
                    "Continuer",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30), // Augmenté de 20 à 30
            ],
          ),
        ),
      ),
    );
  }
}
