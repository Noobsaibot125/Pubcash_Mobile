import 'api_service.dart';

class FeedbackService {
  final ApiService _apiService = ApiService();

  Future<void> sendFeedback({
    required String fullName,
    required String email,
    required String phone,
    required String message,
  }) async {
    try {
      await _apiService.post(
        '/feedback',
        data: {
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'message': message,
        },
      );
    } catch (e) {
      print("Erreur sendFeedback: $e");
      rethrow;
    }
  }

  Future<List<dynamic>> getMyFeedbacks() async {
    try {
      final response = await _apiService.get('/feedback');
      return response.data;
    } catch (e) {
      print("Erreur getMyFeedbacks: $e");
      return [];
    }
  }

  Future<List<dynamic>> getFeedbackMessages(int feedbackId) async {
    try {
      final response = await _apiService.get('/feedback/$feedbackId/messages');
      // Assurer que c'est une liste
      if (response.data is List) {
        return response.data;
      }
      return [];
    } catch (e) {
      print("Erreur getFeedbackMessages: $e");
      return [];
    }
  }

  Future<void> replyToFeedback(int feedbackId, String message) async {
    try {
      await _apiService.post(
        '/feedback/$feedbackId/reply',
        data: {'message': message},
      );
    } catch (e) {
      print("Erreur replyToFeedback: $e");
      rethrow;
    }
  }
}
