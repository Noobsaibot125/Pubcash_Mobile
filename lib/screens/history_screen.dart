import 'package:flutter/material.dart';
import '../services/promotion_service.dart';
import '../utils/colors.dart';
import 'simple_video_player.dart'; // Importe le nouveau fichier // Nous allons crÃ©er ce fichier juste aprÃ¨s
import 'package:flutter/services.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final PromotionService _promotionService = PromotionService();
  bool _isLoading = true;
  List<dynamic> _historyList = [];

  @override
  void initState() {
    super.initState();
     SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

    _loadHistory();
  }
@override
void dispose() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  super.dispose();
}
 Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final interactions = await _promotionService.getInteractionHistory();
      final now = DateTime.now();
      final List<dynamic> filteredVideos = interactions.where((item) {
        if (item['type_interaction'] != 'vue') return false;
        DateTime? dateInteraction = DateTime.tryParse(item['date_interaction'].toString());
        if (dateInteraction != null) {
          final difference = now.difference(dateInteraction).inDays;
          if (difference > 7) return false;
        }
        return true;
      }).toList();
      filteredVideos.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['date_interaction'].toString()) ?? DateTime(2000);
        DateTime dateB = DateTime.tryParse(b['date_interaction'].toString()) ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
      if (mounted) {
        setState(() {
          _historyList = filteredVideos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(String? dateStr) {
     // Ta logique...
     if (dateStr == null) return '';
     final date = DateTime.tryParse(dateStr);
     if (date == null) return '';
     final now = DateTime.now();
     final diff = now.difference(date);
     if (diff.inDays > 0) return "Il y a ${diff.inDays} j";
     return "A l'instant";
  }

  void _playVideo(Map<String, dynamic> videoData) {
     // Ta logique...
      if (videoData['url_video'] != null && videoData['url_video'].toString().isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => SimpleVideoPlayer(
           videoUrl: videoData['url_video'],
           title: videoData['titre'] ?? 'Relecture',
           promotionId: videoData['id_promotion'] ?? videoData['id'],
           clientId: videoData['id_client'] ?? videoData['client_id'] ?? videoData['promoter_id'],
           clientName: videoData['nom_promoteur'] ?? videoData['nom_entreprise'] ?? videoData['titre'],
           clientAvatar: videoData['photo_promoteur'] ?? videoData['profile_image_url'],
        )));
      }
  }
  // --- FIN LOGIQUE ---

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white, // BLANC
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F9FF),
        appBar: AppBar(
          title: const Text(
            "Historique Vidéos",
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
        // SafeArea ajouté pour protéger la liste en bas
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _historyList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text(
                            "Aucune vidéo regardée récemment",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _historyList.length,
                      itemBuilder: (context, index) {
                        final item = _historyList[index];
                        final String title = item['titre'] ?? "Vidéo sans titre";
                        final String thumbnailUrl = item['thumbnail_url'] ?? "";

                        return GestureDetector(
                          onTap: () => _playVideo(item),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: thumbnailUrl.isNotEmpty
                                          ? Image.network(
                                              thumbnailUrl,
                                              width: 80,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, o, s) => Container(width: 80, height: 60, color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 20)),
                                            )
                                          : Container(width: 80, height: 60, color: Colors.black12, child: const Icon(Icons.videocam, color: Colors.grey)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.remove_red_eye, size: 14, color: AppColors.primary),
                                          SizedBox(width: 4),
                                          Text("Vidéo Regardée", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(_formatTimeAgo(item['date_interaction']), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}