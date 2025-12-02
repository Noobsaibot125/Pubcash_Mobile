import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class TransactionDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailsScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    // 1. Récupération des données
    final String amount = transaction['montant']?.toString() ?? '0';
    final String status = transaction['statut']?.toString().toLowerCase() ?? 'en attente';
    
    String date = 'Date inconnue';
    if (transaction['date'] != null) {
      date = transaction['date'].toString().replaceAll('T', ' ').split('.')[0];
    }

    final String operator = transaction['operator'] ?? 'Mobile Money';
    final String idTrans = transaction['transaction_id'] ?? 'N/A'; 
    
    // 👇 RECUPERATION DU NUMERO
    // On regarde d'abord 'numero_telephone', sinon on met une valeur par défaut
    final String destinataire = transaction['numero_telephone'] ?? "Non spécifié"; 
    
    final String frais = "0 FCFA"; 

    // 2. Couleurs
    Color statusColor = const Color(0xFFFFA000);
    Color statusBg = const Color(0xFFFFF8E1);
    String statusLabel = "En attente";
    IconData statusIcon = Icons.access_time_filled;

    if (status == 'traite' || status == 'succes') {
      statusColor = Colors.green;
      statusBg = const Color(0xFFE8F5E9);
      statusLabel = "Succès";
      statusIcon = Icons.check_circle;
    } else if (status == 'rejete' || status == 'echec') {
      statusColor = Colors.red;
      statusBg = const Color(0xFFFFEBEE);
      statusLabel = "Échoué";
      statusIcon = Icons.cancel;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Détails Transaction", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5F7FA),
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(
              "$amount FCFA",
              style: const TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text("Retrait $operator", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Statut", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 16, color: statusColor),
                            const SizedBox(width: 6),
                            Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      )
                    ],
                  ),
                  _buildDivider(),
                  _buildDetailRow("ID transaction", idTrans, isCopyable: true, context: context),
                  _buildDivider(),
                  _buildDetailRow("Montant du retrait", "$amount FCFA"),
                  _buildDivider(),
                  _buildDetailRow("Frais de retrait", frais),
                  _buildDivider(),
                  // 👇 AFFICHAGE DU DESTINATAIRE
                  _buildDetailRow("Destinataire", destinataire), 
                  _buildDivider(),
                  _buildDetailRow("Mode de retrait", operator),
                  _buildDivider(),
                  _buildDetailRow("Date et heure", date),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 15),
      child: Divider(height: 1, color: Color(0xFFEEEEEE)),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isCopyable = false, BuildContext? context}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600, fontSize: 14)),
        Row(
          children: [
            Text(value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14)),
            if (isCopyable && context != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID Copié !"), duration: Duration(seconds: 1)));
                },
                child: const Icon(Icons.copy, size: 16, color: Colors.grey),
              )
            ]
          ],
        ),
      ],
    );
  }
}