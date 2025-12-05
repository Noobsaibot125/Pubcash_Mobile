import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/colors.dart';
import '../services/promotion_service.dart';

class SimpleVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int? promotionId; // ID pour poster un commentaire
  final String? promoterName; // Nom du promoteur
  final String? promoterAvatar; // Avatar du promoteur

  const SimpleVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.promotionId,
    this.promoterName,
    this.promoterAvatar,
  });

  @override
  State<SimpleVideoPlayer> createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  // === ÉTAT COMMENTAIRES ===
  final TextEditingController _commentController = TextEditingController();
  final PromotionService _promotionService = PromotionService();
  
  bool _isSendingComment = false;
  bool _hasCommented = false; 
  bool _isLoadingCommentStatus = true; // Pour attendre la vérification avant d'afficher
  
  int _wordCount = 0;
  static const int _maxWords = 200;

  @override
  void initState() {
    super.initState();
    // Initialisation Vidéo
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _startHideTimer();
      });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    // Écouter les changements de texte pour compter les mots
    _commentController.addListener(_updateWordCount);

    // Vérifier si l'utilisateur a déjà commenté
    _checkIfAlreadyCommented();
  }

  // Vérifier dans la BDD
 Future<void> _checkIfAlreadyCommented() async {
  if (widget.promotionId == null) {
    if (mounted) setState(() => _isLoadingCommentStatus = false);
    return;
  }

  try {
    print("⏳ Vérification commentaire pour Promo ID: ${widget.promotionId}...");
    
    final hasComment = await _promotionService.hasComment(widget.promotionId!);
    
    print("✅ Résultat reçu : $hasComment"); // Doit être true si déjà commenté

    if (mounted) {
      setState(() {
        _hasCommented = hasComment;
        _isLoadingCommentStatus = false;
      });
    }
  } catch (e) {
    print("❌ Erreur dans _checkIfAlreadyCommented: $e");
    // En cas d'erreur, on laisse la boîte visible (false) ou on la cache par sécurité (true)
    if (mounted) setState(() => _isLoadingCommentStatus = false);
  }
}

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    _commentController.removeListener(_updateWordCount);
    _commentController.dispose();
    super.dispose();
  }

  void _updateWordCount() {
    final text = _commentController.text.trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    setState(() {
      _wordCount = words;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    final newPos = _controller.value.position + Duration(seconds: seconds);
    _controller.seekTo(newPos);
    _startHideTimer();
  }

  // Envoyer un commentaire
Future<void> _sendComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty || widget.promotionId == null) return;

    if (_wordCount > _maxWords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Votre commentaire est trop long.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSendingComment = true);

    try {
      await _promotionService.addComment(widget.promotionId!, comment);

      _commentController.clear();

      if (mounted) {
        setState(() {
          _hasCommented = true; // On masque la barre immédiatement
        });

        // --- NOUVEAU : LE POPUP (DIALOG) ---
        showDialog(
          context: context,
          barrierDismissible: false, // L'utilisateur doit cliquer sur OK
          builder: (BuildContext ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text("Merci !"),
                ],
              ),
              content: const Text(
                "Votre commentaire a été envoyé avec succès.",
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Ferme le popup
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains("403")) {
          // Cas où il a déjà commenté (doublon)
          setState(() {
            _hasCommented = true;
          });
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Info"),
              content: const Text("Vous avez déjà commenté cette promotion."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("OK"),
                )
              ],
            ),
          );
        } else {
          // Erreur technique
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur lors de l\'envoi.'),
                backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }
  void _onFollowTapped() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fonctionnalité "Suivre" disponible prochainement !'),
        backgroundColor: Colors.blueGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // === PARTIE VIDÉO (Flexible) ===
            Expanded(
              child: Stack(
                children: [
                  // 1. LA VIDÉO
                  Center(
                    child: _isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          )
                        : const CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                  ),

                  // 2. ZONE TACTILE GÉNÉRALE
                  GestureDetector(
                    onTap: _toggleControls,
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      color: _showControls
                          ? Colors.black45
                          : Colors.transparent,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),

                  // 3. LES CONTRÔLES
                  if (_showControls && _isInitialized)
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // --- EN HAUT : Titre et Retour ---
                          AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            leading: IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            title: Text(
                              widget.title,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),

                          // --- AU CENTRE : Play/Pause et +/- 10s ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(
                                  Icons.replay_10,
                                  color: Colors.white,
                                ),
                                onPressed: () => _seekRelative(-10),
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                iconSize: 70,
                                icon: Icon(
                                  _controller.value.isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_fill,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller.value.isPlaying
                                        ? _controller.pause()
                                        : _controller.play();
                                    _startHideTimer();
                                  });
                                },
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(
                                  Icons.forward_10,
                                  color: Colors.white,
                                ),
                                onPressed: () => _seekRelative(10),
                              ),
                            ],
                          ),

                          // --- EN BAS : Slider et Temps ---
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(
                                        _controller.value.position,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(
                                        _controller.value.duration,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _controller.value.position.inSeconds
                                      .toDouble(),
                                  min: 0.0,
                                  max: _controller.value.duration.inSeconds
                                      .toDouble(),
                                  activeColor: AppColors.primary,
                                  inactiveColor: Colors.white24,
                                  onChanged: (value) {
                                    _hideTimer?.cancel();
                                    setState(() {
                                      _controller.seekTo(
                                        Duration(seconds: value.toInt()),
                                      );
                                    });
                                  },
                                  onChangeEnd: (value) {
                                    _startHideTimer();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // === BARRE INFO PROMOTEUR + SUIVRE ===
            Container(
              color: const Color(0xFF1C1C1E),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Avatar promoteur
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[700],
                    backgroundImage:
                        widget.promoterAvatar != null &&
                                widget.promoterAvatar!.isNotEmpty
                            ? NetworkImage(widget.promoterAvatar!)
                            : null,
                    child:
                        widget.promoterAvatar == null ||
                                widget.promoterAvatar!.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                  ),
                  const SizedBox(width: 10),

                  // Nom promoteur
                  Expanded(
                    child: Text(
                      widget.promoterName ?? 'Promoteur',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Bouton Suivre
                  ElevatedButton(
                    onPressed: _onFollowTapped,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Colors.white, width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Suivre',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // === BARRE DE COMMENTAIRE STYLE FACEBOOK ===
            // On affiche seulement si l'ID promo existe,
            // que le chargement du statut est terminé,
            // et que l'utilisateur n'a pas encore commenté.
            if (widget.promotionId != null && !_isLoadingCommentStatus && !_hasCommented)
              Container(
                color: const Color(0xFF2C2C2E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // Champ de texte
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3C),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Ajouter un commentaire...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Bouton Envoyer
                        _isSendingComment
                            ? const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : IconButton(
                                onPressed:
                                    _commentController.text.trim().isNotEmpty
                                        ? _sendComment
                                        : null,
                                icon: Icon(
                                  Icons.send_rounded,
                                  color:
                                      _commentController.text.trim().isNotEmpty
                                          ? AppColors.primary
                                          : Colors.grey[600],
                                ),
                              ),
                      ],
                    ),

                    // Compteur de mots
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text(
                        '$_wordCount / $_maxWords mots',
                        style: TextStyle(
                          color: _wordCount > _maxWords
                              ? Colors.red
                              : Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

             // Optionnel : Message discret si déjà commenté
             if (widget.promotionId != null && !_isLoadingCommentStatus && _hasCommented)
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.symmetric(vertical: 12),
                 color: const Color(0xFF1C1C1E),
                 child: const Text(
                   "Vous avez déjà commenté cette promotion.",
                   style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
                   textAlign: TextAlign.center,
                 ),
               ),
          ],
        ),
      ),
    );
  }
}