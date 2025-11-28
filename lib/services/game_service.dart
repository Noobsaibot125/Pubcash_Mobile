import '../models/game.dart';
import 'api_service.dart';

class GameService {
  final ApiService _apiService = ApiService();

  Future<List<Game>> getGames() async {
    try {
      final response = await _apiService.get('/jeux');
      final List<dynamic> data = response.data;
      return data.map((json) => Game.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
