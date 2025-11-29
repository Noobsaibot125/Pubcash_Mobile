import 'package:flutter/material.dart';
import '../services/promotion_service.dart';
import '../utils/colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final PromotionService _promotionService = PromotionService();
  bool _isLoading = true;
  List<dynamic> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      // On récupère les gains qui contiennent normalement l'historique "per_pack"
      final earningsData = await _promotionService.getEarnings();

      // On suppose que la structure est { 'per_pack': [...] }
      // Si ce n'est pas le cas, il faudra adapter selon le retour réel de l'API
      List<dynamic> allItems = earningsData['per_pack'] ?? [];

      // Filtrage : On ne garde que les 7 derniers jours
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final filteredItems = allItems.where((item) {
        // On essaie de parser la date. Format attendu : ISO ou compatible
        // Si pas de date, on garde par défaut ou on rejette ? Disons on garde pour tester.
        if (item['date'] == null) return false;

        try {
          final itemDate = DateTime.parse(item['date'].toString());
          return itemDate.isAfter(sevenDaysAgo);
        } catch (e) {
          return false; // Date invalide, on ignore
        }
      }).toList();

      // Tri du plus récent au plus ancien
      filteredItems.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['date'].toString());
          final dateB = DateTime.parse(b['date'].toString());
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      if (mounted) {
        setState(() {
          _historyItems = filteredItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur chargement historique: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          // _historyItems reste vide ou on pourrait mettre des fausses données pour tester l'UI
        });
      }
    }
  }

  String _formatTimeAgo(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return "Il y a ${difference.inDays}j";
      } else if (difference.inHours > 0) {
        return "Il y a ${difference.inHours}h";
      } else if (difference.inMinutes > 0) {
        return "Il y a ${difference.inMinutes} min";
      } else {
        return "A l'instant";
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text(
          "Historique",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _historyItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 15),
                  Text(
                    "Aucun historique récent",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "L'historique s'efface après 7 jours",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _historyItems.length,
              itemBuilder: (context, index) {
                final item = _historyItems[index];
                // final String titre = item['pack_name'] ?? 'Vidéo visionnée'; // Unused
                final String sousTitre =
                    item['video_title'] ?? 'Boisson énergétique';
                final double montant =
                    double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
                final String? dateStr = item['date'];

                bool isGain = montant >= 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Icône
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isGain
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          isGain
                              ? Icons.play_circle_outline
                              : Icons.file_download_outlined,
                          color: isGain ? Colors.green : Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 15),

                      // Textes
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Vidéo visionnée :",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              sousTitre,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimeAgo(dateStr),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Montant
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "${isGain ? '+' : ''}${montant.toInt()} FCFA",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isGain ? Colors.green : Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
