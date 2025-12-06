import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import '../models/promotion.dart';
import '../services/promotion_service.dart';
import '../services/auth_service.dart';
import '../utils/colors.dart';
import '../widgets/quiz_dialog.dart';

// 1. AJOUT DU MIXIN WidgetsBindingObserver
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

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  final PromotionService _promotionService = PromotionService();
  
  bool _isInitialized = false;
  bool _videoEnded = false;
  bool _hasLiked = false;
  bool _hasShared = false; // C'est l'indicateur visuel
  
  bool _isCancelling = false; 
  bool _isSharingLoading = false;
  
  // 2. NOUVEAU FLAG : Pour savoir si on attend le retour de WhatsApp
  bool _waitingForShareReturn = false; 
  // Pour éviter de valider deux fois (via le await et via l'observer)
  bool _isValidatingShare = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 3. ON ECOUTE LE CYCLE DE VIE DE L'APP
    WidgetsBinding.instance.addObserver(this); 

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

  @override
  void dispose() {
    // 4. ON ARRETE D'ECOUTER
    WidgetsBinding.instance.removeObserver(this);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // 5. DETECTE QUAND L'UTILISATEUR REVIENT SUR L'APP
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // L'utilisateur vient de revenir (ex: de WhatsApp)
      if (_waitingForShareReturn) {
        print("🔄 Retour détecté via Lifecycle Observer");
        _onShareCompleted();
      }
    }
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
    if (!mounted) return;
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

  void _finishProcess() {
    print("✅ Fermeture et retour accueil");
    if (!mounted) return;
    widget.onVideoViewed();
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(true); // Renvoie true pour recharger Home
    }
  }

  Future<void> _handleLike() async {
    try {
      await _promotionService.likePromotion(widget.promotion.id);
      if (mounted) {
        setState(() {
          _hasLiked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vidéo likée ! Maintenant, partagez-la."), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  // 6. LA LOGIQUE DE VALIDATION ISOLEE
  Future<void> _onShareCompleted() async {
    // Sécurité anti-doublon
    if (_isValidatingShare || _hasShared) return;
    _isValidatingShare = true;
    _waitingForShareReturn = false; // On n'attend plus

    if (!mounted) return;

    // Mise à jour UI immédiate
    setState(() {
      _hasShared = true;
      // On garde _isSharingLoading true tant que l'API n'a pas répondu
    });

    try {
      // 1. Enregistrement du partage
      try {
        await _promotionService.sharePromotion(widget.promotion.id);
      } catch (e) {
        print("Warning API share: $e");
      }

      // 2. Quiz ou Validation
      if (widget.promotion.gameId != null && widget.promotion.gameType == 'quiz') {
        setState(() => _isSharingLoading = false);
        _showQuiz();
      } else {
        // Validation vue + Crédit points
        await _promotionService.markPromotionAsViewed(widget.promotion.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text("Félicitations ! Points crédités."), 
               backgroundColor: Colors.green, 
               duration: Duration(seconds: 2)
             ),
          );
        }
        
        // Petit délai UX avant fermeture
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) _finishProcess();
      }
    } catch (e) {
      setState(() => _isSharingLoading = false);
      _isValidatingShare = false; // On permet de réessayer en cas d'erreur
      
      if (e.toString().contains("DEVICE_FRAUD")) {
         _showFraudDialog();
      } else {
         print("Erreur technique validation: $e");
         // En cas d'erreur obscure, on ferme quand même pour ne pas bloquer
         _finishProcess();
      }
    }
  }

  Future<void> _handleShare() async {
    if (_isSharingLoading) return;
    setState(() => _isSharingLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final codeParrainage = user?.codeParrainage ?? '';
      
      final String shareUrl = "https://pub-cash.com/promo/${widget.promotion.id}?ref=$codeParrainage";
      final String text = "Regarde ça et gagne de l'argent ! : ${widget.promotion.titre}\n$shareUrl";

      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/video_${widget.promotion.id}.mp4';

      if (!File(savePath).existsSync()) {
        await Dio().download(widget.promotion.urlVideo, savePath);
      }

      if (!mounted) return;

      // 7. ON ACTIVE LE MODE "ATTENTE DE RETOUR"
      _waitingForShareReturn = true;

      await Share.shareXFiles(
        [XFile(savePath)],
        text: text,
        subject: widget.promotion.titre,
      );

      // 8. TENTATIVE DE VALIDATION DIRECTE (Si le téléphone est rapide)
      // Si cette ligne s'exécute, _onShareCompleted gérera la suite.
      // Si elle ne s'exécute pas (app pause), didChangeAppLifecycleState prendra le relais.
      if (mounted) {
         await _onShareCompleted();
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _isSharingLoading = false);
      _waitingForShareReturn = false;
      print("Erreur pré-partage: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors du partage."), backgroundColor: Colors.orange),
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
          Navigator.of(ctx).pop(); 
          await Future.delayed(const Duration(milliseconds: 300));
          
          if (!mounted) return;

          if (isCorrect) {
              try {
                final success = await _promotionService.submitQuiz(
                  widget.promotion.gameId!, 
                  widget.promotion.bonneReponse!
                );

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bonne réponse ! Points crédités."), backgroundColor: Colors.green),
                  );
                }

                await _promotionService.markPromotionAsViewed(widget.promotion.id);
                await Future.delayed(const Duration(seconds: 1));
                
                if (mounted) _finishProcess();

              } catch(e) {
                 if (e.toString().contains("DEVICE_FRAUD")) {
                    if (mounted) _showFraudDialog();
                 } else {
                    if (mounted) _finishProcess(); 
                 }
              }
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Mauvaise réponse..."), backgroundColor: Colors.red),
             );
             await Future.delayed(const Duration(seconds: 1));
             if (mounted) _finishProcess();
          }
        },
      ),
    );
  }

  void _showFraudDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
              Navigator.of(ctx).pop(); 
              try {
                await _promotionService.cancelPromotion(widget.promotion.id);
              } catch (e) {
                print("Erreur annulation auto: $e");
              }
              if (mounted) _finishProcess(); 
            },
            child: const Text("Compris", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClose() async {
    if (_videoEnded) {
       Navigator.pop(context); 
       return;
    }

    setState(() => _isCancelling = true);
    try {
      await _promotionService.cancelPromotion(widget.promotion.id);
    } catch(e) {
      print("Erreur cancel: $e");
    }
    
    if (mounted) {
      widget.onVideoViewed(); 
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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
                      _isSharingLoading 
                      ? const Column(
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 10),
                            Text("Validation en cours...", style: TextStyle(color: Colors.white70))
                          ],
                        )
                      : ElevatedButton.icon(
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