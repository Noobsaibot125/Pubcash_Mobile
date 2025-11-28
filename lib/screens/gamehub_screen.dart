import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class GameHubScreen extends StatefulWidget {
  const GameHubScreen({Key? key}) : super(key: key);

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  
  // États Roue
  late AnimationController _wheelController;
  double _wheelAngle = 0;
  bool _isSpinning = false;
  
  // États Puzzle
  List<dynamic> _puzzles = [];
  
  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _loadPuzzles();
  }

  Future<void> _loadPuzzles() async {
    try {
      final res = await _apiService.get('/games/list?type=puzzle');
      setState(() {
        _puzzles = res.data ?? [];
      });
    } catch (e) {
      print("Erreur chargement puzzles: $e");
    }
  }

  void _spinWheel() async {
    if (_isSpinning) return;
    setState(() => _isSpinning = true);

    // Simulation visuelle (tourne beaucoup)
    _wheelController.reset();
    _wheelController.forward();

    try {
      final res = await _apiService.post('/games/wheel');
      final points = res.data['points_gagnes'];
      
      // Calculer l'angle final basé sur les points (Simplifié)
      // 0 pts -> ~45deg, 1 pt -> ~135deg, etc. (A ajuster selon ton image de roue)
      double targetAngle = 2 * pi * 5; // 5 tours complets par défaut
      
      // Ici tu devras mapper 'points' à un angle spécifique si tu as une image précise
      
      setState(() {
        _wheelAngle = targetAngle; 
      });

      await Future.delayed(const Duration(seconds: 4));
      
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(points > 0 ? "Bravo !" : "Dommage"),
          content: Text("Vous avez gagné $points points."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        )
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur ou déjà joué aujourd'hui")));
    } finally {
      setState(() => _isSpinning = false);
    }
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Espace Jeux", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- SECTION ROUE ---
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text("Roue de la Fortune", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _spinWheel,
                    child: RotationTransition(
                      turns: Tween(begin: 0.0, end: 5.0).animate(CurvedAnimation(parent: _wheelController, curve: Curves.easeOutCubic)),
                      child: Container(
                        height: 200,
                        width: 200,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          // Remplace par une Image.asset('assets/wheel.png') ici
                        ),
                        child: const Center(child: Icon(Icons.casino, size: 50, color: Colors.orange)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _spinWheel,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.orange),
                    child: Text(_isSpinning ? "Ça tourne..." : "Tourner la roue"),
                  )
                ],
              ),
            ),

            // --- SECTION PUZZLES ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text("Puzzles du jour", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _puzzles.length,
              itemBuilder: (context, index) {
                final game = _puzzles[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: Image.network(
                        game['image_url'] ?? '', 
                        width: 50, 
                        height: 50, 
                        fit: BoxFit.cover,
                        errorBuilder: (c,e,s) => const Icon(Icons.image),
                    ),
                    title: Text(game['titre'] ?? 'Puzzle'),
                    subtitle: Text("${game['points_recompense']} points - ${game['duree_limite']}s"),
                    trailing: ElevatedButton(
                      onPressed: game['deja_joue'] ? null : () {
                        // Ouvrir écran Puzzle (à faire : PuzzleGameScreen)
                      },
                      child: Text(game['deja_joue'] ? "Fait" : "Jouer"),
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}