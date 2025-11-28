import '../models/quiz.dart';
import 'api_service.dart';

class QuizService {
  final ApiService _apiService = ApiService();

  // The backend seems to embed the quiz in the promotion, so we won't have a separate getQuiz endpoint.
  // We'll get the quiz data from the Promotion object.

  // Soumettre les réponses du quiz
  Future<bool> submitQuiz(int promoId, Map<int, int> answers) async {
    // answers format: { questionId: optionId, ... }
    try {
      final response = await _apiService.post(
        '/promotions/$promoId/quiz/submit',
        data: {'reponses': answers},
      );
      // Assuming a 200 OK response means success
      return response.statusCode == 200;
    } catch (e) {
      rethrow;
    }
  }
}
