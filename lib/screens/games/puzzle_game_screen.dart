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

  // État du jeu
  bool _isPlaying = false;
  bool _isGameOver = false;
  int _timeLeft = 0;
  Timer? _timer;

  // Grille (3x3 pour simplifier sur mobile)
  final int _gridSize = 3;
  List<int> _tiles = []; // 0 à 8, où 8 est la case vide

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.game.dureeLimite ?? 60;
    // Initialiser la grille ordonnée
    _tiles = List.generate(_gridSize * _gridSize, (index) => index);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startGame() async {
    try {
      // 1. Appel API start
      await _gameService.startPuzzle(widget.game.id);

      setState(() {
        _isPlaying = true;
        _shuffleTiles();
        _startTimer();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur démarrage: $e")));
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
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
    });

    if (success) {
      try {
        final result = await _gameService.submitPuzzle(widget.game.id);
        if (mounted) {
          _showResultDialog(true, result['points'] ?? 0);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Erreur validation: $e")));
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
        content: Text(
          success
              ? "Vous avez résolu le puzzle et gagné $points points !"
              : "Vous n'avez pas fini à temps. Réessayez plus tard !",
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, success); // Retour avec succès si gagné
            },
            child: const Text("Quitter"),
          ),
        ],
      ),
    );
  }

  // --- LOGIQUE PUZZLE ---

  void _shuffleTiles() {
    // Mélange simple mais on doit s'assurer que c'est résoluble.
    // Pour 3x3, une méthode simple est de faire des mouvements aléatoires valides depuis l'état résolu.
    _tiles = List.generate(_gridSize * _gridSize, (index) => index);
    int emptyIndex = _tiles.length - 1;
    int moves = 50; // Nombre de mélanges

    for (int i = 0; i < moves; i++) {
      final neighbors = _getNeighbors(emptyIndex);
      final randomNeighbor =
          neighbors[DateTime.now().microsecond % neighbors.length];
      _swap(emptyIndex, randomNeighbor);
      emptyIndex = randomNeighbor;
    }
  }

  List<int> _getNeighbors(int index) {
    List<int> neighbors = [];
    int row = index ~/ _gridSize;
    int col = index % _gridSize;

    if (row > 0) neighbors.add(index - _gridSize); // Haut
    if (row < _gridSize - 1) neighbors.add(index + _gridSize); // Bas
    if (col > 0) neighbors.add(index - 1); // Gauche
    if (col < _gridSize - 1) neighbors.add(index + 1); // Droite

    return neighbors;
  }

  void _onTileTap(int index) {
    if (!_isPlaying) return;

    final emptyIndex = _tiles.indexOf(
      _gridSize * _gridSize - 1,
    ); // L'index de la case vide (8)

    // Vérifier si adjacent
    if (_isAdjacent(index, emptyIndex)) {
      setState(() {
        _swap(index, emptyIndex);
        if (_checkWin()) {
          _endGame(success: true);
        }
      });
    }
  }

  bool _isAdjacent(int idx1, int idx2) {
    int row1 = idx1 ~/ _gridSize;
    int col1 = idx1 % _gridSize;
    int row2 = idx2 ~/ _gridSize;
    int col2 = idx2 % _gridSize;
    return (row1 == row2 && (col1 - col2).abs() == 1) ||
        (col1 == col2 && (row1 - row2).abs() == 1);
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.titre),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                "$_timeLeft s",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _timeLeft < 10 ? Colors.red : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isPlaying || _isGameOver
                      ? GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _gridSize,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                              ),
                          itemCount: _tiles.length,
                          itemBuilder: (context, index) {
                            final tileValue = _tiles[index];
                            final isEmpty =
                                tileValue == _gridSize * _gridSize - 1;

                            if (isEmpty) return Container(color: Colors.white);

                            // Calculer la position originale de cette tuile pour découper l'image
                            // (C'est complexe avec NetworkImage, on va utiliser des numéros pour l'instant ou une image locale si possible)
                            // Pour simplifier : on affiche juste le numéro ou une couleur.
                            // Si on veut l'image découpée, il faudrait un widget spécial.
                            // On va faire simple : Tuiles colorées avec Numéro.

                            return GestureDetector(
                              onTap: () => _onTileTap(index),
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      Colors.blue[100 * ((tileValue % 9) + 1)],
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Text(
                                    "${tileValue + 1}",
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
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
                              Image.network(
                                widget.game.imageUrl ?? '',
                                height: 200,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image, size: 100),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _startGame,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 15,
                                  ),
                                ),
                                child: const Text(
                                  "COMMENCER",
                                  style: TextStyle(fontSize: 18),
                                ),
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
              padding: EdgeInsets.all(20.0),
              child: Text(
                "Remettez les tuiles dans l'ordre (1 à 8) !",
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
