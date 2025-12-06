import 'api_service.dart';

class FollowService {
  final ApiService _apiService = ApiService();

  Future<void> followPromoter(int clientId) async {
    try {
      await _apiService.post('/follows/$clientId');
    } catch (e) {
      print("Erreur followPromoter: $e");
      rethrow;
    }
  }

  Future<void> unfollowPromoter(int clientId) async {
    try {
      await _apiService.delete('/follows/$clientId');
    } catch (e) {
      print("Erreur unfollowPromoter: $e");
      rethrow;
    }
  }

  Future<bool> isFollowing(int clientId) async {
    try {
      final response = await _apiService.get('/follows/$clientId/status');
      return response.data['isFollowing'] == true;
    } catch (e) {
      print("Erreur isFollowing: $e");
      return false;
    }
  }

  Future<List<dynamic>> getFollowing() async {
    try {
      final response = await _apiService.get('/follows/me/following');
      return response.data;
    } catch (e) {
      print("Erreur getFollowing: $e");
      return [];
    }
  }
}
