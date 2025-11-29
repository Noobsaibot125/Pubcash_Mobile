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
  
  // Taille de la grille (3x3)
  final int _gridSize = 3;
  
  // Cette liste contient les VALEURS des tuiles.
  // La valeur 0 correspond au coin haut-gauche de l'image originale.
  // La valeur 8 (pour une grille 3x3) est la case vide.
  List<int> _tiles = []; 

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.game.dureeLimite ?? 60;
    // Initialisation : 0, 1, 2, 3, 4, 5, 6, 7, 8
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
    _tiles = List.generate(_gridSize * _gridSize, (index) => index);
    int emptyIndex = _tiles.length - 1;
    // On effectue 100 mouvements aléatoires valides pour mélanger
    // Cela garantit que le puzzle reste résolvable
    for (int i = 0; i < 100; i++) {
      final neighbors = _getNeighbors(emptyIndex);
      final randomNeighbor = neighbors[DateTime.now().microsecond % neighbors.length];
      _swap(emptyIndex, randomNeighbor);
      emptyIndex = randomNeighbor;
    }
  }

  List<int> _getNeighbors(int index) {
    List<int> neighbors = [];
    int row = index ~/ _gridSize;
    int col = index % _gridSize;
    if (row > 0) neighbors.add(index - _gridSize);
    if (row < _gridSize - 1) neighbors.add(index + _gridSize);
    if (col > 0) neighbors.add(index - 1);
    if (col < _gridSize - 1) neighbors.add(index + 1);
    return neighbors;
  }

  void _onTileTap(int index) {
    if (!_isPlaying) return;
    // Trouver où est la case vide (valeur 8) dans la liste mélangée
    final currentEmptyIndex = _tiles.indexOf(_gridSize * _gridSize - 1);
    
    if (_isAdjacent(index, currentEmptyIndex)) {
      setState(() {
        _swap(index, currentEmptyIndex);
        if (_checkWin()) _endGame(success: true);
      });
    }
  }

  bool _isAdjacent(int idx1, int idx2) {
    int row1 = idx1 ~/ _gridSize; int col1 = idx1 % _gridSize;
    int row2 = idx2 ~/ _gridSize; int col2 = idx2 % _gridSize;
    return (row1 == row2 && (col1 - col2).abs() == 1) || (col1 == col2 && (row1 - row2).abs() == 1);
  }

  void _swap(int idx1, int idx2) {
    final temp = _tiles[idx1]; _tiles[idx1] = _tiles[idx2]; _tiles[idx2] = temp;
  }

  bool _checkWin() {
    // Le puzzle est gagné si la liste est triée (0, 1, 2, ...)
    for (int i = 0; i < _tiles.length; i++) { if (_tiles[i] != i) return false; }
    return true;
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
                  padding: const EdgeInsets.all(4), // Padding réduit pour coller les images
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[400]!, width: 2),
                  ),
                  child: _isPlaying || _isGameOver
                      ? GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          // Espacement très fin (2px) pour l'esthétique du puzzle image
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridSize, 
                            crossAxisSpacing: 2, 
                            mainAxisSpacing: 2
                          ),
                          itemCount: _tiles.length,
                          itemBuilder: (context, index) {
                            // tileValue représente le morceau de l'image (0=haut-gauche, 1=haut-milieu...)
                            final tileValue = _tiles[index];
                            final isEmpty = tileValue == _gridSize * _gridSize - 1;

                            if (isEmpty) {
                              return Container(color: Colors.white.withOpacity(0.3)); // Case vide légèrement visible
                            }

                            // --- LOGIQUE D'AFFICHAGE DE L'IMAGE ---
                            // 1. Calcul de la position originale (Ligne/Colonne) de ce morceau
                            int originalRow = tileValue ~/ _gridSize;
                            int originalCol = tileValue % _gridSize;

                            // 2. Création de l'Alignment pour centrer la bonne partie de l'image
                            Alignment alignment = Alignment(
                              (originalCol * 2 / (_gridSize - 1)) - 1,
                              (originalRow * 2 / (_gridSize - 1)) - 1,
                            );

                            return GestureDetector(
                              onTap: () => _onTileTap(index),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  color: AppColors.primary, // Couleur de fond si l'image ne charge pas
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Si pas d'image, on affiche l'ancien style (chiffres sur fond orange)
                                      if (widget.game.imageUrl == null || widget.game.imageUrl!.isEmpty) {
                                        return Center(
                                          child: Text(
                                            "${tileValue + 1}",
                                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        );
                                      }

                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // COUCHE 1 : L'IMAGE ZOOMÉE ET DÉCALÉE
                                          OverflowBox(
                                            maxWidth: constraints.maxWidth * _gridSize,
                                            maxHeight: constraints.maxHeight * _gridSize,
                                            alignment: alignment,
                                            child: Image.network(
                                              widget.game.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
                                            ),
                                          ),
                                          
                                          // COUCHE 2 : LE NUMÉRO (Optionnel, semi-transparent pour aider)
                                          Center(
                                            child: Text(
                                              "${tileValue + 1}",
                                              style: TextStyle(
                                                fontSize: 24, 
                                                fontWeight: FontWeight.bold, 
                                                color: Colors.white.withOpacity(0.8),
                                                shadows: const [Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black)],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.game.imageUrl != null)
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.primary, width: 2),
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      widget.game.imageUrl!, 
                                      height: 200, 
                                      width: 200, 
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
              child: Text("Reconstituez l'image !", style: TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic))
            ),
        ],
      ),
    );
  }
}