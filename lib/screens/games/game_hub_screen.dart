import 'package:flutter/material.dart';
import '../../services/game_service.dart';
import '../../models/game.dart';
import '../../utils/colors.dart';
import 'wheel_game_screen.dart';
import 'puzzle_game_screen.dart';

class GameHubScreen extends StatefulWidget {
  const GameHubScreen({super.key});

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  final GameService _gameService = GameService();
  
  int _points = 0;
  bool _wheelPlayed = false; // NOUVEAU : Pour savoir si la roue est jouée
  List<Game> _games = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. On charge les infos utilisateur (Points + Roue)
      final userData = await _gameService.getUserGameData();
      // 2. On charge les jeux
      final games = await _gameService.getGames(type: 'puzzle');
      
      if (mounted) {
        setState(() {
          _points = userData['points'];
          _wheelPlayed = userData['wheel_spun']; // Mise à jour du statut
          _games = games;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur GameHub: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8), // Fond très léger
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // --- HEADER 3D ---
            SliverAppBar(
              expandedHeight: 220.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF8C42), Color(0xFFFF512F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 50),
                      const Icon(
                        Icons.videogame_asset,
                        size: 50,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "ESPACE JEUX & BONUS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Jouez et gagnez des points !",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      // Badge Points
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10),
                          ],
                        ),
                        child: Text(
                          "$_points Points",
                          style: const TextStyle(
                            color: Color(0xFFFF512F),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // --- ROUE ---
                  _build3DWheelCard(),
                  const SizedBox(height: 30),
                  const Text(
                    "Puzzles Disponibles",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 15),
                ]),
              ),
            ),

            // --- LISTE PUZZLES ---
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _games.isEmpty
                ? const SliverToBoxAdapter(
                    child: Center(child: Text("Aucun puzzle pour l'instant.")),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _build3DPuzzleCard(_games[index]),
                        childCount: _games.length,
                      ),
                    ),
                  ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET ROUE MODIFIÉ ---
  Widget _build3DWheelCard() {
    return GestureDetector(
      // Si déjà joué, on affiche un message, sinon on navigue
      onTap: _wheelPlayed 
          ? () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Vous avez déjà tourné la roue aujourd'hui !")),
               );
            }
          : () async {
              print("Navigation vers la roue de la fortune");
              final result = await Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const WheelGameScreen())
              );
              // Si on revient de la roue, on recharge les données pour mettre à jour l'affichage
              if (result == true || result == null) _loadData();
            },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 10))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            children: [
              Positioned.fill(
                // APPLICATION DU FILTRE NOIR & BLANC SI JOUÉ
                child: ColorFiltered(
                  colorFilter: _wheelPlayed
                      ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) // Grayscale
                      : const ColorFilter.mode(Colors.transparent, BlendMode.multiply), // Normal
                  child: Image.asset(
                    'assets/images/Wheel.png', 
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Center(child: Icon(Icons.error, color: Colors.white)),
                  ),
                ),
              ),
              
              // Texte par dessus
              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.casino, color: Colors.white, size: 30),
                    ),
                    const Spacer(),
                    const Text(
                      "ROUE DE LA FORTUNE",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      _wheelPlayed ? "Revenez demain" : "Tentez votre chance !",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // OVERLAY "COCHÉ" (CHECKMARK) SI JOUÉ
              if (_wheelPlayed)
                Container(
                  color: Colors.black54, // Voile sombre
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 60,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "DÉJÀ JOUÉ",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 16
                          ),
                        )
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3DPuzzleCard(Game game) {
    return GestureDetector(
      onTap: game.dejaJoue
          ? null
          : () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PuzzleGameScreen(game: game)),
              );
              if (result == true) _loadData();
            },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(game.imageUrl ?? '', fit: BoxFit.cover),
                    if (game.dejaJoue)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      game.titre,
                      maxLines: 2,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.orange[300]),
                        const SizedBox(width: 4),
                        Text(
                          "${game.pointsRecompense}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}