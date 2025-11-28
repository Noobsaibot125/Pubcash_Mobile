import 'api_service.dart';

class VideoService {
  final ApiService _apiService = ApiService();

  // Like une vidéo
  Future<void> likeVideo(int promotionId) async {
    try {
      await _apiService.post('/promotions/$promotionId/like');
    } catch (e) {
      throw Exception('Erreur lors du like: ${e.toString()}');
    }
  }

  // Partage une vidéo
  Future<void> shareVideo(int promotionId) async {
    try {
      await _apiService.post('/promotions/$promotionId/partage');
    } catch (e) {
      throw Exception('Erreur lors du partage: ${e.toString()}');
    }
  }

  // Marque une vidéo comme vue (crédite l'utilisateur)
  Future<void> markAsViewed(int promotionId) async {
    try {
      await _apiService.post('/promotions/$promotionId/view');
    } catch (e) {
      throw Exception('Erreur lors du marquage de la vue: ${e.toString()}');
    }
  }

  // Récupère les points de jeu de l'utilisateur
  Future<int> getPoints() async {
    try {
      final response = await _apiService.get('/games/points');
      return response.data['points'] ?? 0;
    } catch (e) {
      throw Exception(
        'Erreur lors de la récupération des points: ${e.toString()}',
      );
    }
  }

  // Soumet une réponse au quiz
  Future<Map<String, dynamic>> submitQuizAnswer({
    required int gameId,
    required String answer,
  }) async {
    try {
      final response = await _apiService.post(
        '/games/$gameId/submit',
        data: {'answer': answer},
      );
      return response.data;
    } catch (e) {
      throw Exception('Erreur lors de la soumission du quiz: ${e.toString()}');
    }
  }
}
