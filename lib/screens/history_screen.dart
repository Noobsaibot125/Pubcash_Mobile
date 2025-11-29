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
  List<dynamic> _mergedHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      // 1. Charger les gains
      final earningsData = await _promotionService.getEarnings();
      List<dynamic> gains = earningsData['per_pack'] ?? [];
      
      // Ajouter un tag 'type' pour les identifier
      gains = gains.map((e) => {...e, 'data_type': 'gain'}).toList();

      // 2. Charger l'historique des vidéos (Vues/Likes)
      final interactions = await _promotionService.getInteractionHistory();
      // Ajouter un tag 'type'
      final List<dynamic> videos = interactions.map((e) => {...e, 'data_type': 'interaction'}).toList();

      // 3. Fusionner les listes
      List<dynamic> allItems = [...gains, ...videos];

      // 4. Tri par date décroissante
      allItems.sort((a, b) {
        DateTime? dateA;
        DateTime? dateB;

        // Gestion des dates selon la source (API gains vs API historique)
        if (a['data_type'] == 'gain') {
           dateA = DateTime.tryParse(a['date'].toString()); 
        } else {
           dateA = DateTime.tryParse(a['date_interaction'].toString());
        }

        if (b['data_type'] == 'gain') {
           dateB = DateTime.tryParse(b['date'].toString());
        } else {
           dateB = DateTime.tryParse(b['date_interaction'].toString());
        }
        
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _mergedHistory = allItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur History: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper date
  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return "Il y a ${difference.inDays}j";
    if (difference.inHours > 0) return "Il y a ${difference.inHours}h";
    if (difference.inMinutes > 0) return "Il y a ${difference.inMinutes} min";
    return "A l'instant";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text("Historique Global", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _mergedHistory.isEmpty
              ? Center(child: Text("Aucune activité récente", style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _mergedHistory.length,
                  itemBuilder: (context, index) {
                    final item = _mergedHistory[index];
                    
                    // --- LOGIQUE D'AFFICHAGE SELON LE TYPE ---
                    bool isGain = item['data_type'] == 'gain';
                    
                    String title;
                    String subtitle;
                    IconData icon;
                    Color color;
                    String rightText;
                    DateTime? dateObj;

                    if (isGain) {
                      // C'est un gain financier
                      title = "Gain Reçu";
                      subtitle = "Pack: ${item['nom_pack'] ?? 'Standard'}";
                      icon = Icons.monetization_on;
                      color = Colors.green;
                      rightText = "+${item['total_gagne']} FCFA";
                      // Note: l'API getUserEarnings actuelle groupe par pack, donc pas de date précise par ligne
                      // Si tu veux le détail ligne par ligne, il faut modifier getUserEarnings coté backend
                      // Pour l'instant on affiche générique
                      dateObj = null; 
                    } else {
                      // C'est une interaction (Vue, Like, Partage)
                      String type = item['type_interaction'] ?? 'vue';
                      title = type == 'vue' ? "Vidéo Regardée" : (type == 'like' ? "Vidéo Likée" : "Vidéo Partagée");
                      subtitle = item['titre'] ?? "Promotion sans titre";
                      dateObj = DateTime.tryParse(item['date_interaction'].toString());
                      
                      if (type == 'vue') {
                        icon = Icons.visibility;
                        color = Colors.blue;
                      } else if (type == 'like') {
                        icon = Icons.favorite;
                        color = Colors.pink;
                      } else {
                        icon = Icons.share;
                        color = Colors.orange;
                      }
                      rightText = ""; // Pas de montant affiché ici sauf si tu veux l'ajouter
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (dateObj != null)
                                  Text(_formatTimeAgo(dateObj), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                              ],
                            ),
                          ),
                          if (rightText.isNotEmpty)
                             Text(rightText, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}