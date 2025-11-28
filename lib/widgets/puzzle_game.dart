import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';

class PuzzleGame extends StatefulWidget {
  final dynamic game; // Les infos du jeu (image, id, etc.)
  final VoidCallback onFinish;

  const PuzzleGame({Key? key, required this.game, required this.onFinish}) : super(key: key);

  @override
  State<PuzzleGame> createState() => _PuzzleGameState();
}

class _PuzzleGameState extends State<PuzzleGame> {
  final ApiService _apiService = ApiService();
  List<int> tiles = []; // 0 à 8
  bool isStarted = false;
  bool isGameOver = false;
  int timeLeft = 30; // Valeur par défaut
  Timer? _timer;
  int? selectedIndex; // Pour l'échange au clic

  @override
  void initState() {
    super.initState();
    timeLeft = widget.game['duree_limite'] ?? 30;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() async {
    try {
      // Appel API start (optionnel selon ton backend)
      // await _apiService.post('/games/puzzle/start', data: {'gameId': widget.game['id']});
      
      setState(() {
        isStarted = true;
        // Créer et mélanger les tuiles [0, 1, 2... 8]
        tiles = List.generate(9, (index) => index);
        tiles.shuffle(); 
      });

      _startTimer();
    } catch (e) {
      print("Erreur start: $e");
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft <= 0) {
        _endGame(false, "Temps écoulé !");
      } else {
        setState(() => timeLeft--);
      }
    });
  }

  void _handleTileTap(int index) {
    if (isGameOver) return;

    if (selectedIndex == null) {
      // Premier clic (sélection)
      setState(() => selectedIndex = index);
    } else {
      // Deuxième clic (échange)
      setState(() {
        final temp = tiles[selectedIndex!];
        tiles[selectedIndex!] = tiles[index];
        tiles[index] = temp;
        selectedIndex = null;
      });
      _checkWin();
    }
  }

  void _checkWin() async {
    // Est-ce que la liste est triée [0, 1, 2, ... 8] ?
    bool isSorted = true;
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i] != i) {
        isSorted = false;
        break;
      }
    }

    if (isSorted) {
      _endGame(true, "Bravo !");
      try {
        await _apiService.post('/games/puzzle/submit', data: {'gameId': widget.game['id']});
      } catch (e) {
        print("Erreur submit: $e");
      }
    }
  }

  void _endGame(bool win, String message) {
    _timer?.cancel();
    setState(() => isGameOver = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(win ? "Victoire ! 🎉" : "Perdu 😢"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Ferme dialog
              widget.onFinish(); // Callback vers GameHub
            },
            child: const Text("Fermer"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isStarted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("🧩 ${widget.game['titre']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: widget.game['image_url'],
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  backgroundColor: Colors.blueAccent,
                ),
                child: const Text("Commencer", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Temps: ${timeLeft}s", style: TextStyle(color: timeLeft < 10 ? Colors.red : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              TextButton(onPressed: () => _endGame(false, "Abandon"), child: const Text("Abandonner"))
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final tileValue = tiles[index]; // Quelle partie de l'image afficher ?
                
                // Calcul de la position de découpe de l'image (Alignment)
                // 0 = Haut Gauche (-1, -1), 8 = Bas Droite (1, 1)
                final x = (tileValue % 3) - 1.0; 
                final y = (tileValue ~/ 3) - 1.0;
                
                return GestureDetector(
                  onTap: () => _handleTileTap(index),
                  child: Container(
                    decoration: BoxDecoration(
                      border: selectedIndex == index ? Border.all(color: Colors.blue, width: 3) : null,
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(widget.game['image_url']),
                        fit: BoxFit.cover,
                        alignment: Alignment(x, y), // C'est ici la magie du découpage
                      ),
                    ),
                    // Optionnel : afficher les numéros pour aider
                    // child: Center(child: Text("$tileValue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}