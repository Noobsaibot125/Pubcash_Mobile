import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/colors.dart';
import '../services/promotion_service.dart';
import '../services/follow_service.dart';
import 'messaging/chat_screen.dart';

class SimpleVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final int? promotionId; // ID pour poster un commentaire
  final int? clientId;       // C'est l'ID du client à suivre
  final String? clientName;  // Nom de l'entreprise ou utilisateur
  final String? clientAvatar;
  final String? promoterName; // Nom du promoteur
  final String? promoterAvatar; // Avatar du promoteur
  final int? promoterId; // ID du promoteur pour le suivre

  const SimpleVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.promotionId,
    this.promoterName,
    this.promoterAvatar,
    this.promoterId,
    this.clientId,      // Modifié
    this.clientName,    // Modifié
    this.clientAvatar,  // Modifié
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
  bool _isLoadingCommentStatus = true; 

  int _wordCount = 0;
  static const int _maxWords = 200;

  // === ÉTAT FOLLOW ===
  final FollowService _followService = FollowService();
  bool _isFollowing = false;
  bool _isLoadingFollow = false;

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

    // Vérifier le statut de suivi (si on a un ID client valide)
    if (widget.clientId != null) {
      _checkFollowStatus();
    }
  }

  Future<void> _checkFollowStatus() async {
    try {
      // On vérifie si on suit ce client (table 'clients')
      final isFollowing = await _followService.isFollowing(widget.clientId!);
      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
        });
      }
    } catch (e) {
      print("Erreur checkFollowStatus: $e");
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.clientId == null) return;

    setState(() => _isLoadingFollow = true);
    try {
      if (_isFollowing) {
        await _followService.unfollowPromoter(widget.clientId!); // Assurez-vous que votre service gère l'ID client
      } else {
        await _followService.followPromoter(widget.clientId!);
      }
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  // Vérifier dans la BDD pour les commentaires
  Future<void> _checkIfAlreadyCommented() async {
    if (widget.promotionId == null) {
      if (mounted) setState(() => _isLoadingCommentStatus = false);
      return;
    }

    try {
      final hasComment = await _promotionService.hasComment(widget.promotionId!);
      if (mounted) {
        setState(() {
          _hasCommented = hasComment;
          _isLoadingCommentStatus = false;
        });
      }
    } catch (e) {
      print("❌ Erreur dans _checkIfAlreadyCommented: $e");
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

  Future<void> _sendComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty || widget.promotionId == null) return;

    if (_wordCount > _maxWords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre commentaire est trop long.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSendingComment = true);

    try {
      await _promotionService.addComment(widget.promotionId!, comment);
      _commentController.clear();

      if (mounted) {
        setState(() {
          _hasCommented = true;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 10),
                  Text("Merci !"),
                ],
              ),
              content: const Text("Votre commentaire a été envoyé avec succès.", style: TextStyle(fontSize: 16)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("OK", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains("403")) {
          setState(() { _hasCommented = true; });
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Info"),
              content: const Text("Vous avez déjà commenté cette promotion."),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("OK")),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'envoi.'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
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
                        : const CircularProgressIndicator(color: AppColors.primary),
                  ),

                  // 2. ZONE TACTILE
                  GestureDetector(
                    onTap: _toggleControls,
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      color: _showControls ? Colors.black45 : Colors.transparent,
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
                          // HAUT
                          AppBar(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            leading: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            title: Text(widget.title, style: const TextStyle(color: Colors.white)),
                          ),

                          // CENTRE
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(Icons.replay_10, color: Colors.white),
                                onPressed: () => _seekRelative(-10),
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                iconSize: 70,
                                icon: Icon(
                                  _controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                                    _startHideTimer();
                                  });
                                },
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                iconSize: 40,
                                icon: const Icon(Icons.forward_10, color: Colors.white),
                                onPressed: () => _seekRelative(10),
                              ),
                            ],
                          ),

                          // BAS (Slider)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white)),
                                    Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                                Slider(
                                  value: _controller.value.position.inSeconds.toDouble(),
                                  min: 0.0,
                                  max: _controller.value.duration.inSeconds.toDouble(),
                                  activeColor: AppColors.primary,
                                  inactiveColor: Colors.white24,
                                  onChanged: (value) {
                                    _hideTimer?.cancel();
                                    setState(() {
                                      _controller.seekTo(Duration(seconds: value.toInt()));
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

            // === BARRE INFO CLIENT (Basée sur table 'clients') + SUIVRE ===
            Container(
              color: const Color(0xFF1C1C1E),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Avatar Client
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: widget.clientAvatar != null && widget.clientAvatar!.isNotEmpty
                        ? NetworkImage(widget.clientAvatar!)
                        : null,
                    child: widget.clientAvatar == null || widget.clientAvatar!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 10),

                  // Nom Client (Entreprise ou Utilisateur)
                  Expanded(
                    child: Text(
                      widget.clientName ?? 'Client',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Boutons Chat et Suivre (Visibles uniquement si clientId existe)
                  if (widget.clientId != null) ...[
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              contactId: widget.clientId!,
                              contactType: 'client', // Type explicite pour votre logique de chat
                              contactName: widget.clientName ?? 'Client',
                              contactPhoto: widget.clientAvatar,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoadingFollow ? null : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.grey[400] : Colors.transparent,
                        side: BorderSide(color: _isFollowing ? Colors.transparent : Colors.white, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        elevation: 0,
                      ),
                      child: _isLoadingFollow
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isFollowing ? 'Suivi' : 'Suivre',
                              style: TextStyle(
                                color: _isFollowing ? Colors.black54 : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),

            // === BARRE DE COMMENTAIRE ===
            if (widget.promotionId != null && !_isLoadingCommentStatus && !_hasCommented)
              Container(
                color: const Color(0xFF2C2C2E),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3C),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: TextField(
                              controller: _commentController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              maxLines: 2,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: 'Ajouter un commentaire...',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isSendingComment
                            ? const SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
                            : IconButton(
                                onPressed: _commentController.text.trim().isNotEmpty ? _sendComment : null,
                                icon: Icon(
                                  Icons.send_rounded,
                                  color: _commentController.text.trim().isNotEmpty ? AppColors.primary : Colors.grey[600],
                                ),
                              ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text('$_wordCount / $_maxWords mots', style: TextStyle(color: _wordCount > _maxWords ? Colors.red : Colors.grey[500], fontSize: 11)),
                    ),
                  ],
                ),
              ),

            // Message si déjà commenté
            if (widget.promotionId != null && !_isLoadingCommentStatus && _hasCommented)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: const Color(0xFF1C1C1E),
                child: const Text("Vous avez déjà commenté cette promotion.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12), textAlign: TextAlign.center),
              ),
          ],
        ),
      ),
    );
  }
}