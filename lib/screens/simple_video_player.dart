import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/colors.dart';

class SimpleVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;

  const SimpleVideoPlayer({super.key, required this.videoUrl, required this.title});

  @override
  State<SimpleVideoPlayer> createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true; // Pour afficher/cacher les boutons
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
        _startHideTimer(); // On lance le timer pour cacher les boutons
      });

    _controller.addListener(() {
      // Met à jour l'interface quand la vidéo avance (pour le slider)
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  // Fonction pour formater le temps (ex: 01:30)
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
    _startHideTimer(); // Reset du timer si on interagit
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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

            // 2. ZONE TACTILE GÉNÉRALE (Pour faire apparaître les contrôles)
            GestureDetector(
              onTap: _toggleControls,
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: _showControls ? Colors.black45 : Colors.transparent,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // 3. LES CONTRÔLES (S'affichent si _showControls est true)
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
                    ),

                    // --- AU CENTRE : Play/Pause et +/- 10s ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reculer 10s
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.replay_10, color: Colors.white),
                          onPressed: () => _seekRelative(-10),
                        ),
                        const SizedBox(width: 20),
                        // Play / Pause géant
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
                        // Avancer 10s
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.forward_10, color: Colors.white),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_controller.value.position),
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                          Slider(
                            value: _controller.value.position.inSeconds.toDouble(),
                            min: 0.0,
                            max: _controller.value.duration.inSeconds.toDouble(),
                            activeColor: AppColors.primary,
                            inactiveColor: Colors.white24,
                            onChanged: (value) {
                              _hideTimer?.cancel(); // On garde les contrôles pendant qu'on glisse
                              setState(() {
                                _controller.seekTo(Duration(seconds: value.toInt()));
                              });
                            },
                            onChangeEnd: (value) {
                              _startHideTimer(); // On relance le timer quand on lâche
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
    );
  }
}