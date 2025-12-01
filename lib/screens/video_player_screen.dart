import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/promotion.dart';
import '../services/promotion_service.dart';
import 'package:dio/dio.dart'; // IMPORT IMPORTANT
import 'package:path_provider/path_provider.dart';
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
  
  bool _isCancelling = false; 
// NOUVEAU : Pour gérer l'état de chargement du partage
  bool _isSharingLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.promotion.urlVideo))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _startTimer();
      }).catchError((error) {
        print("Erreur chargement vidéo: $error");
      });

    _controller.addListener(_checkVideoEnd);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller.value.isInitialized && !_controller.value.isPlaying && !_videoEnded) {
         _controller.play();
      }
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

 // === MODIFICATION PRINCIPALE ICI ===
  Future<void> _handleShare() async {
    // 1. Afficher le chargement
    setState(() => _isSharingLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final codeParrainage = user?.codeParrainage ?? '';
      
      final String shareUrl = "https://pub-cash.com/promo/${widget.promotion.id}?ref=$codeParrainage";
      final String text = "Regarde ça et gagne de l'argent ! : ${widget.promotion.titre}\n$shareUrl";

      // 2. Téléchargement
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/video_${widget.promotion.id}.mp4';

      if (!File(savePath).existsSync()) {
        await Dio().download(widget.promotion.urlVideo, savePath);
      }

      // Sécurité : Si l'utilisateur a quitté l'écran pendant le téléchargement
      if (!mounted) return; 

      // 3. Partage
      await Share.shareXFiles(
        [XFile(savePath)],
        text: text,
        subject: widget.promotion.titre,
      );

      // 4. Validation API
      await _promotionService.sharePromotion(widget.promotion.id);
      
      if (!mounted) return; // Sécurité encore ici

      setState(() {
        _hasShared = true;
        _isSharingLoading = false;
      });

      // 5. Suite logique
      if (widget.promotion.gameId != null && widget.promotion.gameType == 'quiz') {
        _showQuiz();
      } else {
        await _promotionService.markPromotionAsViewed(widget.promotion.id);
        if (mounted) _finishProcess();
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSharingLoading = false);
      print("Erreur partage: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur ou annulation du partage."), backgroundColor: Colors.orange),
      );
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
             try {
                await _promotionService.markPromotionAsViewed(widget.promotion.id);
             } catch(e) {
                print("Erreur validation vue après quiz: $e");
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

  // --- Fonction pour gérer la fermeture ---
  Future<void> _handleClose() async {
    if (_videoEnded) {
       Navigator.pop(context);
       return;
    }

    setState(() => _isCancelling = true);
    
    await _promotionService.cancelPromotion(widget.promotion.id);
    
    if (!mounted) return;
    
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
    // --- MODIFICATION ICI : On utilise PopScope pour bloquer le retour ---
    return PopScope(
      canPop: false, // Cela désactive le bouton retour physique et le geste retour
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        // Option A : On affiche un message pour dire d'utiliser le X
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez terminer le visionnage avant de quitter."),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.redAccent,
          ),
        );

        // Option B (Alternative) : Si tu préfères que le bouton retour fasse la même chose que le X
        // _handleClose(); 
        // Mais tu as demandé que seule l'option X soit possible, donc je garde l'Option A.
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Lecteur Vidéo
            Center(
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
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
                      // MODIFICATION ICI : On gère l'état de chargement du bouton
                      _isSharingLoading 
                      ? const Column(
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 10),
                            Text("Préparation du partage...", style: TextStyle(color: Colors.white70))
                          ],
                        )
                      : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _handleShare, // Appelle la nouvelle fonction
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
              child: _isCancelling
                ? const CircularProgressIndicator(color: Colors.white)
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: _handleClose,
                  ),
            ),
            
            // 4. Indicateur de progression
             if (_isInitialized && !_videoEnded)
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: VideoProgressIndicator(
                  _controller, 
                  allowScrubbing: false,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.primary,
                    backgroundColor: Colors.grey,
                    bufferedColor: Colors.white24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}