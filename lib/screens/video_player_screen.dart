import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/promotion.dart';
import '../services/promotion_service.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';
import '../widgets/quiz_dialog.dart';

class FullScreenVideoScreen extends StatefulWidget {
  final Promotion promotion;
  final VoidCallback onVideoViewed;

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
  bool _videoEnded = false;
  bool _hasLiked = false;
  bool _hasShared = false;
  
  // Timer optionnel si tu veux afficher un compte à rebours, 
  // sinon il sert juste à rafraichir l'UI
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.promotion.urlVideo))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play(); // Lecture automatique
        _startTimer();
      }).catchError((error) {
        print("Erreur chargement vidéo: $error");
      });

    _controller.addListener(_checkVideoEnd);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // On force la lecture si jamais ça se met en pause tout seul
      if (_controller.value.isInitialized && !_controller.value.isPlaying && !_videoEnded) {
         _controller.play();
      }
      // On rafraichit l'état pour la barre de progression
      if (mounted) setState(() {});
    });
  }

  void _checkVideoEnd() {
    if (_controller.value.isInitialized && 
        !_controller.value.isPlaying && 
        _controller.value.position >= _controller.value.duration) {
      
      if (!_videoEnded) {
        setState(() {
          _videoEnded = true;
        });
        _timer?.cancel();
      }
    }
  }

  // ... (Tes méthodes _handleLike, _handleShare, _showQuiz, _finishProcess restent identiques) ...
  // Je les remets ici pour que tu aies le fichier complet sans erreur

  Future<void> _handleLike() async {
    try {
      await _promotionService.likePromotion(widget.promotion.id);
      setState(() {
        _hasLiked = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vidéo likée ! Maintenant, partagez-la."), backgroundColor: Colors.green),
      );
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  Future<void> _handleShare() async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final codeParrainage = user?.codeParrainage ?? '';
    final String shareUrl = "https://pub-cash.com/promo/${widget.promotion.id}?ref=$codeParrainage";
    final String text = "Regarde ça et gagne de l'argent ! : ${widget.promotion.titre}\n$shareUrl";

    await Share.share(text);

    try {
      await _promotionService.sharePromotion(widget.promotion.id);
      setState(() => _hasShared = true);
      
      if (widget.promotion.gameId != null && widget.promotion.gameType == 'quiz') {
        _showQuiz();
      } else {
        _finishProcess();
      }
    } catch (e) {
      print("Erreur partage API: $e");
    }
  }

  void _showQuiz() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuizDialog(
        promotion: widget.promotion,
        onFinish: (isCorrect) async {
          Navigator.pop(ctx);
          
          if (isCorrect) {
             final success = await _promotionService.submitQuiz(
               widget.promotion.gameId!, 
               widget.promotion.bonneReponse!
             );
             if (success) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Bonne réponse ! Points crédités."), backgroundColor: Colors.green),
               );
             }
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Mauvaise réponse..."), backgroundColor: Colors.red),
             );
          }
          _finishProcess();
        },
      ),
    );
  }

  void _finishProcess() {
    widget.onVideoViewed();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Lecteur Vidéo (Sans contrôles tactiles)
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    // IgnorePointer empêche de cliquer sur la vidéo pour mettre pause
                    child: IgnorePointer( 
                      ignoring: true, 
                      child: VideoPlayer(_controller),
                    ),
                  )
                : const CircularProgressIndicator(color: AppColors.primary),
          ),

          // 2. Overlay Fin de Vidéo
          if (_videoEnded)
            Container(
              color: Colors.black.withOpacity(0.85),
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    "Vidéo terminée !",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 40),

                  if (!_hasLiked)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _handleLike,
                      icon: const Icon(Icons.thumb_up, color: Colors.white),
                      label: const Text("J'aime", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),

                  if (_hasLiked && !_hasShared)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: _handleShare,
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: const Text("Partager", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                ],
              ),
            ),

          // 3. Bouton Fermer
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          // 4. Indicateur de progression (Non interactif)
           if (_isInitialized && !_videoEnded)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: VideoProgressIndicator(
                _controller, 
                allowScrubbing: false, // INTERDIT D'AVANCER
                colors: const VideoProgressColors(
                  playedColor: AppColors.primary,
                  backgroundColor: Colors.grey,
                  bufferedColor: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}