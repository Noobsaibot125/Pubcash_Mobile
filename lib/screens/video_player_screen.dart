import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart'; // Ajoute ce package pour le partage
import '../models/promotion.dart';
import '../services/promotion_service.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import '../widgets/quiz_modal.dart'; // Assure-toi d'avoir ce widget ou crée-le

class FullScreenVideoScreen extends StatefulWidget {
  final Promotion promotion;
  final Function onVideoViewed;

  const FullScreenVideoScreen({
    Key? key,
    required this.promotion,
    required this.onVideoViewed,
  }) : super(key: key);

  @override
  State<FullScreenVideoScreen> createState() => _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen> {
  late VideoPlayerController _controller;
  final PromotionService _promotionService = PromotionService();
  bool _isInitialized = false;
  bool _isEnded = false;
  bool _hasLiked = false;
  bool _isLikeLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    // Force l'URL en String pour éviter les crashs
    final url = widget.promotion.urlVideo;
    
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play(); // Lecture auto
      });

    _controller.addListener(() {
      // Détection de la fin de la vidéo
      if (_controller.value.position >= _controller.value.duration && !_isEnded) {
        setState(() {
          _isEnded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    setState(() => _isLikeLoading = true);
    try {
      await _promotionService.likePromotion(widget.promotion.id);
      setState(() {
        _hasLiked = true;
        _isLikeLoading = false;
      });
    } catch (e) {
      print("Erreur like: $e");
      setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _handleShare() async {
    // Logique de partage native
    final url = "https://pub-cash.com/promo/${widget.promotion.id}"; // Ton URL
    await Share.share('Regarde cette vidéo et gagne de l\'argent ! $url');

    try {
      // Enregistrer le partage côté serveur
      await _promotionService.sharePromotion(widget.promotion.id);
      
      // Fermer le player
      if (mounted) {
        // Déclencher le callback pour dire que c'est vu
        widget.onVideoViewed();
        
        // Vérifier s'il y a un quiz
        if (widget.promotion.gameId != null && widget.promotion.question != null) {
           Navigator.pop(context); // Fermer vidéo
           // Note: Le home screen lancera le quiz grâce au onVideoViewed ou tu peux le lancer ici
           _showQuizDialog();
        } else {
           Navigator.pop(context); // Fermer vidéo simplement
        }
      }
    } catch (e) {
      print("Erreur partage API: $e");
    }
  }

  void _showQuizDialog() {
    // Code pour afficher le quiz modal (à adapter selon ton implémentation QuizModal)
    // Ici on suppose que le HomeScreen gère ça via le callback, sinon :
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => QuizModal(
        promotion: widget.promotion,
        onCompleted: () {}, 
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Lecteur Vidéo
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(color: AppColors.primary),
          ),

          // 2. Bloquer les clics sur la vidéo (Empêche pause/seek)
          if (!_isEnded)
            GestureDetector(
              onTap: () {}, // Ne rien faire, absorbe le clic
              child: Container(color: Colors.transparent),
            ),

          // 3. Overlay de fin (Like & Partage)
          if (_isEnded)
            Container(
              color: Colors.black.withOpacity(0.8),
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Vidéo terminée !",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  
                  // Bouton LIKE
                  if (!_hasLiked)
                    ElevatedButton.icon(
                      onPressed: _isLikeLoading ? null : _handleLike,
                      icon: _isLikeLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                          : const Icon(Icons.thumb_up),
                      label: const Text("J'aime cette vidéo"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                    ),

                  // Bouton PARTAGE (Apparaît seulement après le like)
                  if (_hasLiked)
                    Column(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 50),
                        const SizedBox(height: 20),
                        const Text("Dernière étape pour valider vos gains :", style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _handleShare,
                          icon: const Icon(Icons.share),
                          label: const Text("Partager maintenant"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          ),
                        ),
                      ],
                    )
                ],
              ),
            ),
            
          // 4. Bouton retour (au cas où ça plante)
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}