import 'package:flutter/material.dart';
import 'package:pub_cash_mobile/models/promotion.dart';
import 'package:pub_cash_mobile/models/quiz.dart';
import 'package:pub_cash_mobile/services/quiz_service.dart';
import 'package:pub_cash_mobile/utils/app_colors.dart';
import 'package:pub_cash_mobile/widgets/custom_button.dart';

class QuizScreen extends StatefulWidget {
  final Promotion promotion;
  const QuizScreen({super.key, required this.promotion});

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final QuizService _quizService = QuizService();
  int _currentQuestionIndex = 0;
  final Map<int, int> _answers = {}; // questionId -> optionId
  bool _isLoading = false;

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.promotion.quiz!.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _submitQuiz();
    }
  }

  void _selectAnswer(int questionId, int optionId) {
    setState(() {
      _answers[questionId] = optionId;
    });
  }

  Future<void> _submitQuiz() async {
    setState(() => _isLoading = true);
    try {
      final success = await _quizService.submitQuiz(widget.promotion.id, _answers);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz soumis avec succès!'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true); // Return true on success
      } else {
        throw Exception('La soumission a échoué');
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Quiz quiz = widget.promotion.quiz!;
    final Question currentQuestion = quiz.questions[_currentQuestionIndex];
    final bool isLastQuestion = _currentQuestionIndex == quiz.questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.titre),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}/${quiz.questions.length}',
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / quiz.questions.length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 32),
            Text(
              currentQuestion.texte,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...currentQuestion.options.map((option) {
              final bool isSelected = _answers[currentQuestion.id] == option.id;
              return Card(
                elevation: isSelected ? 4 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  title: Text(option.texte),
                  onTap: () => _selectAnswer(currentQuestion.id, option.id),
                  selected: isSelected,
                  selectedTileColor: AppColors.primary.withOpacity(0.1),
                ),
              );
            }).toList(),
            const Spacer(),
            CustomButton(
              text: isLastQuestion ? 'Terminer' : 'Suivant',
              onPressed: _answers[currentQuestion.id] == null ? null : _nextQuestion,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
