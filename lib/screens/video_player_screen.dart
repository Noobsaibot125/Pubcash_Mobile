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
import '../services/notification_service.dart';

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

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  final PromotionService _promotionService = PromotionService();

  bool _isInitialized = false;
  bool _videoEnded = false;
  bool _hasLiked = false;

  // États UI
  bool _hasShared = false;
  bool _isCancelling = false;
  
  // NOUVEAU : État pour le chargement du partage (bouton cliqué)
  bool _isSharingLoading = false;

  // Logique de contrôle
  bool _waitingForShareReturn = false;
  bool _isValidatingShare = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.promotion.urlVideo))
          ..initialize()
              .then((_) {
                setState(() {
                  _isInitialized = true;
                });
                _controller.play();
                _startTimer();
              })
              .catchError((error) {
                print("Erreur chargement vidéo: $error");
              });

    _controller.addListener(_checkVideoEnd);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _controller.removeListener(_checkVideoEnd);
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_waitingForShareReturn && !_isValidatingShare) {
        print("🔄 Retour détecté : Validation immédiate");
        if (mounted) {
          setState(() {
            _hasShared = true;
            // On peut arrêter le loading ici si on veut, mais _hasShared cachera le tout
             _isSharingLoading = false; 
          });
        }
        _onShareCompleted();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller.value.isInitialized &&
          !_controller.value.isPlaying &&
          !_videoEnded) {
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
        setState(() => _videoEnded = true);
        _timer?.cancel();
      }
    }
  }

  void _finishProcess() {
    if (!mounted) return;
    widget.onVideoViewed();

    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleLike() async {
    try {
      await _promotionService.likePromotion(widget.promotion.id);
      if (mounted) {
        setState(() => _hasLiked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vidéo likée ! Maintenant, partagez-la."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print("Erreur like: $e");
    }
  }

  Future<void> _onShareCompleted() async {
    if (_isValidatingShare) return;
    _isValidatingShare = true;
    _waitingForShareReturn = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Traitement en cours..."),
              duration: Duration(milliseconds: 500)
          )
      );
    }

    try {
      try { await _promotionService.sharePromotion(widget.promotion.id); } catch (e) {}

      if (!mounted) return;

      if (widget.promotion.gameId != null && widget.promotion.gameType == 'quiz') {
        _showQuiz();
      } else {
        await _promotionService.markPromotionAsViewed(widget.promotion.id);
        _finishProcess();
      }

    } catch (e) {
      _isValidatingShare = false;
      // En cas d'erreur de validation, on réaffiche le bouton pour réessayer
      if (mounted) {
        setState(() {
          _isSharingLoading = false;
        });
      }
      print("❌ Erreur validation: $e");

      if (e.toString().contains("DEVICE_FRAUD")) {
        if (mounted) _showFraudDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Erreur de connexion. Validation locale..."),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));
          if (mounted) _finishProcess();
        }
      }
    }
  }

  Future<void> _handleShare() async {
    // 1. On cache le bouton immédiatement et on affiche le texte
    setState(() {
      _isSharingLoading = true;
    });

    try {
      final user = Provider.of<AuthService>(context, listen: false).currentUser;
      final codeParrainage = user?.codeParrainage ?? '';

      final String shareUrl =
          "https://pub-cash.com/promo/${widget.promotion.id}?ref=$codeParrainage";
      final String text =
          "Regarde ça et gagne de l'argent ! : ${widget.promotion.titre}\n$shareUrl";

      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/video_${widget.promotion.id}.mp4';

      if (!File(savePath).existsSync()) {
        // Note: J'ai retiré le SnackBar "Préparation..." car le texte s'affiche désormais à la place du bouton
        await Dio().download(widget.promotion.urlVideo, savePath);
      }

      if (!mounted) return;

      _waitingForShareReturn = true;

      try {
        await _promotionService.sharePromotion(widget.promotion.id);
      } catch (e) {
        print("⚠️ Info share API: $e");
      }

      await Share.shareXFiles(
        [XFile(savePath)],
        text: text,
        subject: widget.promotion.titre,
      );
    } catch (e) {
      if (!mounted) return;
      
      // En cas d'erreur (ex: échec du téléchargement), on réaffiche le bouton
      setState(() {
        _waitingForShareReturn = false;
        _isSharingLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible de lancer le partage."),
          backgroundColor: Colors.orange,
        ),
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
          if (!mounted) return;

          if (isCorrect) {
            try {
              await _promotionService.submitQuiz(
                widget.promotion.gameId!,
                widget.promotion.bonneReponse!,
              );

              await _promotionService.markPromotionAsViewed(widget.promotion.id);
              if (mounted) _finishProcess();

            } catch (e) {
              if (mounted) _finishProcess();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Mauvaise réponse..."),
                backgroundColor: Colors.red,
              ),
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
              } catch (e) {}
              if (mounted) _finishProcess();
            },
            child: const Text(
              "Compris",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
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
    } catch (e) {}

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
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 60,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Vidéo terminée !",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (!_hasLiked)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _handleLike,
                        icon: const Icon(Icons.thumb_up, color: Colors.white),
                        label: const Text(
                          "J'aime",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),

                    if (_hasLiked)
                      // MODIFICATION ICI : Gestion de l'affichage du bouton vs message
                      if (_hasShared)
                        const SizedBox() // Déjà partagé, on n'affiche rien (ou le quiz arrive)
                      else if (_isSharingLoading)
                        // Affichage du message de chargement à la place du bouton
                        const Column(
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 15),
                            Text(
                              "Préparation du partage...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else
                        // Bouton Partager normal
                        ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: _handleShare,
                              icon: const Icon(
                                Icons.share,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Partager",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
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
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
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