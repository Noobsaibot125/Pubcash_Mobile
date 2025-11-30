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
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
        _controller.play();
      });
      
    _controller.addListener(() {
      if(mounted) {
        setState(() {
          _isPlaying = _controller.value.isPlaying;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 1. La Vidéo (Cliquable pour Pause/Play)
                    GestureDetector(
                      onTap: () {
                         _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      },
                      child: VideoPlayer(_controller),
                    ),
                    
                    // 2. Bouton Play/Pause central (si pause)
                    if (!_isPlaying)
                      const Center(child: Icon(Icons.play_circle_fill, color: Colors.white54, size: 60)),

                    // 3. Barre de progression (Interactive ici !)
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true, // L'utilisateur PEUT avancer/reculer
                      colors: const VideoProgressColors(
                        playedColor: AppColors.primary,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}