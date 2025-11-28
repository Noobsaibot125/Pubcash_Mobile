import '../models/promotion.dart';
import 'api_service.dart';

class PromotionService {
  final ApiService _apiService = ApiService();

  // Récupérer les promotions/vidéos avec filtre
  Future<List<Promotion>> getPromotions({String filter = 'toutes'}) async {
    try {
      final response = await _apiService.get(
        '/promotions',
        queryParameters: {'filter': filter},
      );

      final List<dynamic> data = response.data;
      return data.map((json) => Promotion.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Obtenir les gains de l'utilisateur
  Future<Map<String, dynamic>> getEarnings() async {
    try {
      final response = await _apiService.get('/promotions/utilisateur/gains');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Like une vidéo
  Future<void> likePromotion(int promoId) async {
    try {
      await _apiService.post('/promotions/$promoId/like');
    } catch (e) {
      rethrow;
    }
  }

  // Partager une vidéo
  Future<void> sharePromotion(int promoId) async {
    try {
      await _apiService.post('/promotions/$promoId/partage');
    } catch (e) {
      rethrow;
    }
  }

  // Récupérer les promotions/vidéos pour l'utilisateur connecté
  Future<List<Promotion>> getUserPromotions() async {
    try {
      final response = await _apiService.get('/promotions/utilisateur/videos');

      final List<dynamic> data = response.data;
      return data.map((json) => Promotion.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
