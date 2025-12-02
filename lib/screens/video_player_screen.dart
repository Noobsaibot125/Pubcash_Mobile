import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/promotion.dart';
import '../services/promotion_service.dart';
import 'package:dio/dio.dart'; 
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';
import '../widgets/quiz_dialog.dart';
import 'package:flutter/services.dart';

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
  bool _isSharingLoading = false; // Pour l'état de chargement du bouton partager
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Cache la barre de statut pour l'immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
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
      // Sécurité pour forcer la lecture si ça bloque
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

  // === C'EST ICI QUE TOUT SE JOUE POUR LA DISPARITION ===
  void _showFraudDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Bloque la fermeture en cliquant à côté
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Attention"),
          ],
        ),
        content: const Text(
          "Cet appareil a déjà bénéficié de cette offre promotionnelle.\n\nLa vidéo sera retirée de votre liste.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 1. Fermer le popup visuellement
              Navigator.of(ctx).pop(); 

              // 2. AJOUT CAPITAL : On appelle cancelPromotion
              // Cela marque la vidéo comme "annulée" dans la base de données.
              // Comme ça, quand HomeScreen va recharger les données, le serveur ne renverra plus cette vidéo.
              try {
                await _promotionService.cancelPromotion(widget.promotion.id);
              } catch (e) {
                print("Erreur lors de l'annulation automatique: $e");
              }

              // 3. Fermer l'écran et retirer de la liste locale
              if (mounted) _finishProcess(); 
            },
            child: const Text("Compris", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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

      if (!mounted) return; 

      // 3. Partage natif
      await Share.shareXFiles(
        [XFile(savePath)],
        text: text,
        subject: widget.promotion.titre,
      );

      // 4. Enregistrement du partage côté serveur
      await _promotionService.sharePromotion(widget.promotion.id);
      
      if (!mounted) return;

      setState(() {
        _hasShared = true;
        _isSharingLoading = false;
      });

      // 5. Suite logique (Quiz ou Validation directe)
      if (widget.promotion.gameId != null && widget.promotion.gameType == 'quiz') {
        _showQuiz();
      } else {
        // --- TENTATIVE DE VALIDATION DE LA VUE ---
        try {
          await _promotionService.markPromotionAsViewed(widget.promotion.id);
          if (mounted) _finishProcess(); // Succès normal
        } catch (e) {
          // --- DETECTION DE FRAUDE (Code 403) ---
          if (e.toString().contains("DEVICE_FRAUD")) {
             if (mounted) _showFraudDialog(); // Affiche le popup
          } else {
             // Autre erreur (ex: pas d'internet)
             print("Erreur inconnue validation vue: $e");
          }
        }
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSharingLoading = false);
      print("Erreur partage: $e");
      
      // On n'affiche le snackbar que si ce n'est pas l'erreur de fraude qu'on gère déjà
      if (!e.toString().contains("DEVICE_FRAUD")) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Erreur ou annulation du partage."), backgroundColor: Colors.orange),
         );
      }
    }
  }

  void _showQuiz() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuizDialog(
        promotion: widget.promotion,
        onFinish: (isCorrect) async {
          Navigator.pop(ctx); // Ferme le quiz
          
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
             
             // Tentative de validation après le quiz
             try {
                await _promotionService.markPromotionAsViewed(widget.promotion.id);
                _finishProcess();
             } catch(e) {
                if (e.toString().contains("DEVICE_FRAUD")) {
                   _showFraudDialog(); // Affiche le popup même après un quiz réussi si fraude détectée
                }
             }
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Mauvaise réponse..."), backgroundColor: Colors.red),
             );
             _finishProcess();
          }
        },
      ),
    );
  }

  // Cette fonction ferme l'écran et dit au parent (Home) de retirer la vidéo
  void _finishProcess() {
    widget.onVideoViewed(); // Déclenche le retrait dans HomeScreen
    Navigator.pop(context); // Ferme l'écran vidéo
  }

  // Fonction appelée par la croix (annule la promo)
  Future<void> _handleClose() async {
    if (_videoEnded) {
       Navigator.pop(context);
       return;
    }

    setState(() => _isCancelling = true);
    
    // On annule (masque) la promo pour l'utilisateur
    await _promotionService.cancelPromotion(widget.promotion.id);
    
    if (!mounted) return;
    
    // On retire aussi la vidéo de la liste
    widget.onVideoViewed(); 
    
    Navigator.pop(context);
  }

  @override
  void dispose() {
    // Réaffiche la barre de statut système
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual, 
      overlays: SystemUiOverlay.values 
    );
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Désactive le bouton retour physique
      onPopInvoked: (didPop) {
        if (didPop) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez terminer le visionnage avant de quitter."),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.redAccent,
          ),
        );
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
                        ignoring: true, // Empêche de cliquer sur la vidéo pour pause
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

                    // BOUTON LIKE
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

                    // BOUTON PARTAGER (Apparaît après le Like)
                    if (_hasLiked && !_hasShared)
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
                        onPressed: _handleShare, // Appelle la fonction modifiée
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text("Partager", style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                  ],
                ),
              ),

            // 3. Bouton Fermer (Croix en haut à gauche)
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
            
            // 4. Indicateur de progression (barre en bas)
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