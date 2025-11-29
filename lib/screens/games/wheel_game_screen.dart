import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:rxdart/rxdart.dart';
import '../../services/game_service.dart';
import '../../utils/colors.dart';

class WheelGameScreen extends StatefulWidget {
  const WheelGameScreen({super.key});

  @override
  State<WheelGameScreen> createState() => _WheelGameScreenState();
}

class _WheelGameScreenState extends State<WheelGameScreen> {
  final GameService _gameService = GameService();
  final StreamController<int> _selected = StreamController<int>();
  bool _isSpinning = false;
  String? _resultMessage;
  int? _pointsWon;

  // Configuration de la roue (identique au backend: 0, 1, 2, 5 points)
  // Backend logic:
  // 60% Perdu (0)
  // 20% 1 Point
  // 15% 2 Points
  // 5% 5 Points
  // On doit mapper les segments visuels aux valeurs.
  // Disons 8 segments pour faire joli :
  // 0, 1, 0, 2, 0, 1, 0, 5
  final List<int> _wheelValues = [0, 1, 0, 2, 0, 1, 0, 5];

  @override
  void dispose() {
    _selected.close();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _resultMessage = null;
    });

    try {
      // 1. Appel API pour avoir le résultat
      final result = await _gameService.spinWheel();
      final points = result['points_gagnes'] as int;
      final message = result['message'] as String;

      // 2. Trouver un index correspondant aux points gagnés
      // On cherche tous les index qui ont cette valeur
      final possibleIndices = [];
      for (int i = 0; i < _wheelValues.length; i++) {
        if (_wheelValues[i] == points) possibleIndices.add(i);
      }

      // On en choisit un au hasard parmi les possibles
      final targetIndex =
          possibleIndices[Random().nextInt(possibleIndices.length)];

      // 3. Lancer l'animation
      _selected.add(targetIndex);

      // 4. Attendre la fin de l'animation (environ 5s par défaut pour fortune_wheel)
      // On stocke le résultat pour l'afficher après
      _pointsWon = points;
      _resultMessage = message;
    } catch (e) {
      setState(() => _isSpinning = false);
      String errorMsg = e.toString().replaceAll('Exception:', '');
      if (errorMsg.contains("403")) {
        errorMsg = "Vous avez déjà tourné la roue aujourd'hui !";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
  }

  void _onAnimationEnd() {
    setState(() => _isSpinning = false);
    if (_resultMessage != null) {
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _pointsWon! > 0 ? "Félicitations ! 🎉" : "Dommage...",
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pointsWon! > 0)
              Text(
                "Vous avez gagné $_pointsWon points !",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                "Vous n'avez rien gagné cette fois. Revenez demain !",
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context, true); // Close screen & refresh
            },
            child: const Text("Super", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF1A1A2E,
      ), // Fond sombre pour faire ressortir la roue
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "ROUE DE LA FORTUNE",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tentez votre chance !",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),

            SizedBox(
              height: 350,
              child: FortuneWheel(
                selected: _selected.stream,
                onAnimationEnd: _onAnimationEnd,
                items: [
                  for (var val in _wheelValues)
                    FortuneItem(
                      child: Text(
                        val == 0 ? "Perdu" : "$val Pts",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: val == 0 ? Colors.white : Colors.black,
                        ),
                      ),
                      style: FortuneItemStyle(
                        color: val == 0
                            ? Colors.redAccent
                            : (val == 5
                                  ? Colors.amber
                                  : (val == 2
                                        ? Colors.lightBlueAccent
                                        : Colors.greenAccent)),
                        borderColor: Colors.white,
                        borderWidth: 2,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 50),

            ElevatedButton(
              onPressed: _isSpinning ? null : _spin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                _isSpinning ? "Bonne chance..." : "TOURNER LA ROUE",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
