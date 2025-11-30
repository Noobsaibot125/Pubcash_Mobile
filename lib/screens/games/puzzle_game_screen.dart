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
  List<int> _tiles = []; 

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
    _tiles = List.generate(_gridSize * _gridSize, (index) => index);
    int emptyIndex = _tiles.length - 1;
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
                  padding: const EdgeInsets.all(2), // Bordure très fine
                  decoration: BoxDecoration(
                    color: Colors.grey[800], // Fond foncé pour faire ressortir l'image
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
                  ),
                  child: _isPlaying || _isGameOver
                      ? GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          // Espacement minimal (1px) pour le style "Web"
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _gridSize, 
                            crossAxisSpacing: 1, 
                            mainAxisSpacing: 1
                          ),
                          itemCount: _tiles.length,
                          itemBuilder: (context, index) {
                            final tileValue = _tiles[index];
                            final isEmpty = tileValue == _gridSize * _gridSize - 1;

                            // --- MODIFICATION : Case vide totalement transparente ---
                            if (isEmpty) {
                              return Container(color: Colors.transparent); 
                            }

                            int originalRow = tileValue ~/ _gridSize;
                            int originalCol = tileValue % _gridSize;

                            Alignment alignment = Alignment(
                              (originalCol * 2 / (_gridSize - 1)) - 1,
                              (originalRow * 2 / (_gridSize - 1)) - 1,
                            );

                            return GestureDetector(
                              onTap: () => _onTileTap(index),
                              child: Container(
                                // Suppression des bordures arrondies internes pour l'effet "Web"
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (widget.game.imageUrl == null || widget.game.imageUrl!.isEmpty) {
                                      return Center(child: Text("${tileValue + 1}", style: const TextStyle(fontSize: 20, color: Colors.white)));
                                    }

                                    return OverflowBox(
                                      maxWidth: constraints.maxWidth * _gridSize,
                                      maxHeight: constraints.maxHeight * _gridSize,
                                      alignment: alignment,
                                      child: Image.network(
                                        widget.game.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_,__,___) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
                                      ),
                                    );
                                    // --- SUPPRESSION DU TEXTE (NUMÉROS) ICI ---
                                  },
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
                                      height: 250, 
                                      width: 250, 
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