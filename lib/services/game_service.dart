import 'package:dio/dio.dart';
import '../utils/api_constants.dart';
import 'api_service.dart';
import '../models/game.dart';

class GameService {
  final ApiService _apiService = ApiService();

  // Récupérer les points de l'utilisateur
  Future<int> getPoints() async {
    try {
      final response = await _apiService.get(ApiConstants.gamePoints);
      return response.data['points'] ?? 0;
    } catch (e) {
      print("Erreur getPoints: $e");
      return 0;
    }
  }

  // Récupérer la liste des jeux (puzzles)
  Future<List<Game>> getGames({String type = 'puzzle'}) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.gameList}?type=$type',
      );
      final List<dynamic> data = response.data;
      return data.map((json) => Game.fromJson(json)).toList();
    } catch (e) {
      print("Erreur getGames: $e");
      return [];
    }
  }

  // Tourner la roue
  Future<Map<String, dynamic>> spinWheel() async {
    try {
      final response = await _apiService.post(ApiConstants.gameWheel);
      return response.data; // { points_gagnes: int, message: String }
    } catch (e) {
      // Si erreur 403 (déjà joué), on la relance pour l'afficher
      rethrow;
    }
  }

  // Démarrer un puzzle
  Future<int> startPuzzle(int gameId) async {
    try {
      final response = await _apiService.post(
        ApiConstants.gamePuzzleStart,
        data: {'gameId': gameId},
      );
      return response.data['startTime']; // Timestamp
    } catch (e) {
      rethrow;
    }
  }

  // Soumettre un puzzle
  Future<Map<String, dynamic>> submitPuzzle(int gameId) async {
    try {
      final response = await _apiService.post(
        ApiConstants.gamePuzzleSubmit,
        data: {'gameId': gameId},
      );
      return response.data; // { success: bool, points: int, message: String }
    } catch (e) {
      rethrow;
    }
  }
}
