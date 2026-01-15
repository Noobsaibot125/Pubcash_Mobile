import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import '../../services/game_service.dart';
import '../../utils/colors.dart'; // Assure-toi que ce chemin est correct

class WheelGameScreen extends StatefulWidget {
  const WheelGameScreen({super.key});

  @override
  State<WheelGameScreen> createState() => _WheelGameScreenState();
}

class _WheelGameScreenState extends State<WheelGameScreen> {
  final GameService _gameService = GameService();
  // FIX: Utiliser broadcast() pour éviter que le stream ne rejoue les anciennes valeurs
  final StreamController<int> _selected = StreamController<int>.broadcast();
  bool _isSpinning = false;
  String? _resultMessage;
  int? _pointsWon;

  // Configuration des segments
  final List<int> _wheelValues = [0, 1, 0, 2, 0, 1, 0, 5];

  @override
  void dispose() {
    _selected.close();
    super.dispose();
  }

  Future<void> _spin() async {
    // Si ça tourne déjà, on ne fait rien
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _resultMessage = null;
    });

    try {
      // 1. Appel API
      final result = await _gameService.spinWheel();
      final points = result['points_gagnes'] as int;
      final message = result['message'] as String;

      // 2. Calcul de l'index cible
      final possibleIndices = [];
      for (int i = 0; i < _wheelValues.length; i++) {
        if (_wheelValues[i] == points) possibleIndices.add(i);
      }
      final targetIndex =
          possibleIndices[Random().nextInt(possibleIndices.length)];

      // 3. Lancer l'animation via le stream
      _selected.add(targetIndex);

      // Stocker les résultats
      _pointsWon = points;
      _resultMessage = message;
    } catch (e) {
      setState(() => _isSpinning = false);
      String errorMsg = e.toString().replaceAll('Exception:', '');

      // Gestion du cas "Déjà joué" (403)
      if (errorMsg.contains("403") || errorMsg.toLowerCase().contains("déjà")) {
        _showStylishDialog(
          type: DialogType.info,
          title: "Oups !",
          message:
              "Vous avez déjà tourné la roue aujourd'hui.\nRevenez demain !",
          points: 0,
        );
      } else {
        // Erreur générique
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: $errorMsg"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onAnimationEnd() {
    setState(() => _isSpinning = false);
    if (_resultMessage != null && _pointsWon != null) {
      // Afficher le popup de résultat
      if (_pointsWon! > 0) {
        _showStylishDialog(
          type: DialogType.win,
          title: "Félicitations !",
          message: "Vous avez gagné $_pointsWon points !",
          points: _pointsWon!,
        );
      } else {
        _showStylishDialog(
          type: DialogType.lose,
          title: "Dommage...",
          message: "Vous n'avez rien gagné cette fois.\nRevenez demain !",
          points: 0,
        );
      }
    }
  }

  // --- NOUVEAU SYSTÈME DE POPUP STYLÉ ---
  void _showStylishDialog({
    required DialogType type,
    required String title,
    required String message,
    required int points,
  }) {
    Color mainColor;
    IconData icon;
    String btnText;

    switch (type) {
      case DialogType.win:
        mainColor = Colors.amber;
        icon = Icons.emoji_events_rounded;
        btnText = "Génial !";
        break;
      case DialogType.lose:
        mainColor = Colors.redAccent;
        icon = Icons.sentiment_dissatisfied_rounded;
        btnText = "D'accord";
        break;
      case DialogType.info:
        mainColor = Colors.blueAccent;
        icon = Icons.lock_clock;
        btnText = "Compris";
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cercle avec icône
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 50, color: mainColor),
              ),
              const SizedBox(height: 15),

              // Titre
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 25),

              // Bouton
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // Ferme le dialog
                    if (type == DialogType.win || type == DialogType.lose) {
                      Navigator.pop(
                        context,
                        true,
                      ); // Ferme l'écran de jeu et rafraîchit
                    }
                  },
                  child: Text(
                    btnText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
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
              // IgnorePointer empêche le tactile sur la roue
              child: IgnorePointer(
                ignoring: true, // La roue ne réagira plus aux doigts
                child: FortuneWheel(
                  selected: _selected.stream,
                  onAnimationEnd: _onAnimationEnd,
                  physics: NoPanPhysics(), // Sécurité supplémentaire
                  // FIX: Empêcher l'animation automatique au chargement de la page
                  animateFirst: false,
                  items: [
                    for (var val in _wheelValues)
                      FortuneItem(
                        child: Text(
                          val == 0 ? "Perdu" : "$val Pts",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: val == 0 ? Colors.white : Colors.black,
                          ),
                        ),
                        style: FortuneItemStyle(
                          color: val == 0
                              ? const Color(0xFFEF5350) // Rouge plus joli
                              : (val == 5
                                    ? const Color(0xFFFFCA28) // Or
                                    : (val == 2
                                          ? const Color(0xFF42A5F5) // Bleu
                                          : const Color(0xFF66BB6A))), // Vert
                          borderColor: Colors.white,
                          borderWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 50),

            ElevatedButton(
              // Désactive le bouton si ça tourne
              onPressed: _isSpinning ? null : _spin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                disabledBackgroundColor: Colors.grey, // Couleur quand désactivé
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
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

// Enum simple pour gérer les types de popup
enum DialogType { win, lose, info }
