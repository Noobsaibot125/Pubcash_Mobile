import 'package:flutter/material.dart';
import 'package:pub_cash_mobile/models/game.dart';
import 'package:pub_cash_mobile/services/game_service.dart';
import 'package:pub_cash_mobile/utils/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class GamehubScreen extends StatefulWidget {
  const GamehubScreen({super.key});

  @override
  _GamehubScreenState createState() => _GamehubScreenState();
}

class _GamehubScreenState extends State<GamehubScreen> {
  late Future<List<Game>> _gamesFuture;
  final GameService _gameService = GameService();

  @override
  void initState() {
    super.initState();
    _gamesFuture = _gameService.getGames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamehub'),
        backgroundColor: AppColors.primary,
      ),
      body: FutureBuilder<List<Game>>(
        future: _gamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun jeu disponible.'));
          }

          final games = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              childAspectRatio: 0.8,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return _buildGameCard(game);
            },
          );
        },
      ),
    );
  }

  Widget _buildGameCard(Game game) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final Uri url = Uri.parse(game.lienJeu);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Impossible d\'ouvrir le lien: ${game.lienJeu}')),
            );
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                game.imageUrl ?? 'https://via.placeholder.com/300x200.png?text=PubCash+Game',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.gamepad, size: 50, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                game.nom,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
