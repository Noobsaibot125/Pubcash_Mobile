import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/promotion.dart';
import '../services/video_service.dart';
import '../utils/colors.dart';

class VideoCard extends StatefulWidget {
  final Promotion promotion;
  final VoidCallback onLiked;
  final VoidCallback onShared;
  final VoidCallback onViewed;
  final bool isLiked;

  const VideoCard({
    Key? key,
    required this.promotion,
    required this.onLiked,
    required this.onShared,
    required this.onViewed,
    this.isLiked = false,
  }) : super(key: key);

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  final VideoService _videoService = VideoService();

  bool _isPlaying = false;
  bool _hasEnded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.promotion.urlVideo),
    );

    await _videoPlayerController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: false,
      looping: false,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.primary,
        backgroundColor: Colors.grey,
        bufferedColor: AppColors.primary.withOpacity(0.3),
      ),
      placeholder: widget.promotion.thumbnailUrl != null
          ? CachedNetworkImage(
              imageUrl: widget.promotion.thumbnailUrl!,
              fit: BoxFit.cover,
            )
          : Container(color: Colors.black),
    );

    _videoPlayerController!.addListener(() {
      if (_videoPlayerController!.value.isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = _videoPlayerController!.value.isPlaying;
        });
      }

      // Détecte la fin de la vidéo
      if (_videoPlayerController!.value.position ==
              _videoPlayerController!.value.duration &&
          !_hasEnded) {
        _onVideoEnded();
      }
    });

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _onVideoEnded() async {
    setState(() {
      _hasEnded = true;
    });

    try {
      // Marque la vidéo comme vue (crédite l'utilisateur)
      await _videoService.markAsViewed(widget.promotion.id);
      widget.onViewed();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+${widget.promotion.remunerationPack} FCFA ajoutés à votre solde !',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du marquage de la vue: $e');
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    try {
      await _videoService.likeVideo(widget.promotion.id);
      widget.onLiked();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  Future<void> _handleShare() async {
    try {
      await _videoService.shareVideo(widget.promotion.id);
      widget.onShared();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === VIDEO PLAYER ===
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _isLoading
                      ? Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Chewie(controller: _chewieController!),
                ),
              ),

              // Badge durée
              if (widget.promotion.duree > 0)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.promotion.duree}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Badge récompense
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '+${widget.promotion.remunerationPack}F',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // === CONTENU ===
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Text(
                  widget.promotion.titre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Description
                if (widget.promotion.description != null)
                  Text(
                    widget.promotion.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 16),

                // === ACTIONS ===
                Row(
                  children: [
                    // Bouton Like
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.isLiked ? null : _handleLike,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isLiked
                                ? AppColors.secondary.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.isLiked
                                ? AppColors.secondary
                                : AppColors.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Bouton Share
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _handleShare,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.share_outlined,
                            color: AppColors.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Bouton "Regarder et gagner"
                    if (!_isPlaying && !_hasEnded)
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8C42), Color(0xFFFF6B35)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF8C42).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _videoPlayerController?.play();
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 20,
                                ),
                                child: const Text(
                                  'Regarder et gagner',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
