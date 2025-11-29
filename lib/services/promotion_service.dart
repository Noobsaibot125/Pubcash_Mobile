import '../models/promotion.dart';
import 'api_service.dart';
import '../utils/api_constants.dart'; // N'oublie pas d'importer tes constantes

class PromotionService {
  final ApiService _apiService = ApiService();

  Future<List<Promotion>> getPromotions({String filter = 'toutes'}) async {
    try {
      // Utilise la constante pour être sûr de l'URL
      final response = await _apiService.get(
        ApiConstants.promotions, 
        queryParameters: {'filter': filter},
      );

      final List<dynamic> data = response.data;
      return data.map((json) => Promotion.fromJson(json)).toList();
    } catch (e) {
      print('Erreur fetching promotions: $e');
      rethrow;
    }
  }

  // CORRECTION ICI
  Future<Map<String, dynamic>> getEarnings() async {
    try {
      // Utilise la constante définie dans ApiConstants (/promotions/utilisateur/gains)
      final response = await _apiService.get(ApiConstants.userEarnings); 
      return response.data;
    } catch (e) {
      print('Erreur fetching earnings: $e');
      return {'total': 0, 'per_pack': []};
    }
  }

  Future<void> likePromotion(int promoId) async {
    await _apiService.post('${ApiConstants.promotions}/$promoId/like');
  }

  Future<void> sharePromotion(int promoId) async {
    await _apiService.post('${ApiConstants.promotions}/$promoId/partage');
  }
// === NOUVEAU : SOUMETTRE QUIZ ===
  Future<bool> submitQuiz(int gameId, String reponse) async {
    try {
      // Endpoint basé sur GameController.js: exports.submitQuiz
      final response = await _apiService.post(
        '/games/quiz/submit', // Assure-toi que c'est la bonne route dans ton router.js
        data: {
          'gameId': gameId,
          'reponse': reponse,
        },
      );
      return response.data['success'] == true;
    } catch (e) {
      print("Erreur submit quiz: $e");
      return false;
    }
  }
}