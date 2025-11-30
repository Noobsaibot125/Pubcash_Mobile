import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/game.dart';
import '../../services/game_service.dart';
import '../../utils/colors.dart';

class PuzzleGameScreen extends StatefulWidget {
  final Game game;
  const PuzzleGameScreen({super.key, required this.game});

  @override
  State<PuzzleGameScreen> createState() => _PuzzleGameScreenState();
}

class _PuzzleGameScreenState extends State<PuzzleGameScreen> {
  final GameService _gameService = GameService();
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _timeLeft = 0;
  Timer? _timer;
  
  final int _gridSize = 3;
  
  // Liste des positions actuelles.
  List<int> _tiles = []; 
  
  // Pour la logique de "Swap" au clic (gardée en plus du glisser)
  int? _selectedTileIndex;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.game.dureeLimite ?? 60;
    _tiles = List.generate(_gridSize * _gridSize, (index) => index);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    try {
      await _gameService.startPuzzle(widget.game.id);
      setState(() {
        _isPlaying = true;
        _shuffleTiles();
        _startTimer();
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _endGame(success: false);
        }
      });
    });
  }

  void _endGame({required bool success}) async {
    _timer?.cancel();
    setState(() { _isPlaying = false; _isGameOver = true; });

    if (success) {
      try {
        final result = await _gameService.submitPuzzle(widget.game.id);
        if (mounted) _showResultDialog(true, result['points'] ?? 0);
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur validation: $e")));
      }
    } else {
      _showResultDialog(false, 0);
    }
  }

  void _showResultDialog(bool success, int points) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(success ? "Bravo ! 🧩" : "Temps écoulé ⏳"),
        content: Text(success ? "Vous avez gagné $points points !" : "Réessayez plus tard !"),
        actions: [ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context, success); }, child: const Text("Quitter"))],
      ),
    );
  }

  void _shuffleTiles() {
    List<int> temp = List.from(_tiles);
    temp.shuffle(); 
    _tiles = temp;
    _selectedTileIndex = null;
  }

  // --- LOGIQUE D'ECHANGE ---
  void _swap(int idx1, int idx2) {
    final temp = _tiles[idx1]; 
    _tiles[idx1] = _tiles[idx2]; 
    _tiles[idx2] = temp;
  }

  bool _checkWin() {
    for (int i = 0; i < _tiles.length; i++) { 
      if (_tiles[i] != i) return false; 
    }
    return true;
  }

  // --- GESTION DU CLIC (Optionnel si on veut garder le clic simple) ---
  void _onTileTap(int index) {
    if (!_isPlaying) return;

    setState(() {
      if (_selectedTileIndex == null) {
        _selectedTileIndex = index;
      } else {
        if (_selectedTileIndex != index) {
          _swap(_selectedTileIndex!, index);
          if (_checkWin()) _endGame(success: true);
        }
        _selectedTileIndex = null;
      }
    });
  }

  // --- WIDGET POUR AFFICHER L'IMAGE DÉCOUPÉE ---
  // J'ai extrait cette logique pour la réutiliser dans le Draggable (feedback) et le DragTarget
  Widget _buildTileVisual(int tileContentId, BoxConstraints constraints, {bool isOpacity = false}) {
    if (widget.game.imageUrl == null || widget.game.imageUrl!.isEmpty) {
      return Container(
        color: AppColors.primary,
        child: Center(child: Text("${tileContentId + 1}", style: const TextStyle(color: Colors.white, fontSize: 20))),
      );
    }

    int originalRow = tileContentId ~/ _gridSize;
    int originalCol = tileContentId % _gridSize;

    return Opacity(
      opacity: isOpacity ? 0.3 : 1.0, // Transparence si c'est la case qu'on déplace
      child: Stack(
        children: [
          Positioned(
            left: - (originalCol * constraints.maxWidth),
            top: - (originalRow * constraints.maxHeight),
            width: constraints.maxWidth * _gridSize,
            height: constraints.maxHeight * _gridSize,
            child: Image.network(
              widget.game.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_,__,___) => Container(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.game.titre),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "$_timeLeft s", 
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _timeLeft < 10 ? Colors.red : AppColors.primary)
            ),
          ),
          
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300], 
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: _isPlaying || _isGameOver
                      ? GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridSize, 
                            crossAxisSpacing: 2, 
                            mainAxisSpacing: 2
                          ),
                          itemCount: _tiles.length,
                          itemBuilder: (context, index) {
                            final int tileContentId = _tiles[index];
                            final bool isSelected = _selectedTileIndex == index;

                            // On utilise LayoutBuilder pour connaître la taille exacte de la case pour le découpage
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                // 1. DRAG TARGET : Accepte qu'on dépose une tuile ici
                                return DragTarget<int>(
                                  onWillAccept: (data) => !_isGameOver && _isPlaying, // Accepter si le jeu est en cours
                                  onAccept: (draggedIndex) {
                                    setState(() {
                                      _swap(draggedIndex, index);
                                      if (_checkWin()) _endGame(success: true);
                                    });
                                  },
                                  builder: (context, candidateData, rejectedData) {
                                    // 2. DRAGGABLE : Permet de déplacer cette tuile
                                    return LongPressDraggable<int>(
                                      data: index, // On passe l'index actuel
                                      feedback: Material(
                                        elevation: 5,
                                        color: Colors.transparent,
                                        child: SizedBox(
                                          width: constraints.maxWidth,
                                          height: constraints.maxHeight,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.blueAccent, width: 2)
                                            ),
                                            child: _buildTileVisual(tileContentId, constraints),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Container(
                                        color: Colors.grey[300], // Case grise quand on la déplace
                                      ),
                                      // L'élément au repos (qu'on voit normalement)
                                      child: GestureDetector(
                                        onTap: () => _onTileTap(index),
                                        child: Container(
                                          decoration: isSelected 
                                            ? BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 3)) 
                                            : (candidateData.isNotEmpty 
                                                ? BoxDecoration(border: Border.all(color: Colors.green, width: 3)) // Effet visuel si on survole
                                                : null),
                                          child: ClipRect(
                                            child: _buildTileVisual(tileContentId, constraints),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.game.imageUrl != null)
                                Container(
                                  width: 250,
                                  height: 250,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.primary, width: 2),
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      widget.game.imageUrl!, 
                                      fit: BoxFit.cover,
                                      errorBuilder: (_,__,___) => const Icon(Icons.image, size: 80, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 30),
                              ElevatedButton(
                                onPressed: _startGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary, 
                                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15), 
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                                ),
                                child: const Text("COMMENCER", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
          
          if (_isPlaying) 
            const Padding(
              padding: EdgeInsets.all(20), 
              child: Text(
                "Glissez une case sur une autre pour échanger !", 
                style: TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic)
              )
            ),
        ],
      ),
    );
  }
}