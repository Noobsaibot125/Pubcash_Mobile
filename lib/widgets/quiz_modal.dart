import 'package:flutter/material.dart';
import '../models/promotion.dart';
import '../services/video_service.dart';
import '../utils/colors.dart';
import 'dart:convert';

class QuizModal extends StatefulWidget {
  final Promotion promotion;
  final VoidCallback onCompleted;

  const QuizModal({
    Key? key,
    required this.promotion,
    required this.onCompleted,
  }) : super(key: key);

  @override
  State<QuizModal> createState() => _QuizModalState();
}

class _QuizModalState extends State<QuizModal> {
  final VideoService _videoService = VideoService();

  String? _selectedAnswer;
  bool _isSubmitting = false;
  bool _showResult = false;
  bool _isCorrect = false;
  int _pointsEarned = 0;

  List<String> get _answers {
    if (widget.promotion.reponses == null) return [];
    try {
      final List<dynamic> decoded = json.decode(widget.promotion.reponses!);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print('Erreur parsing réponses: $e');
      return [];
    }
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || widget.promotion.gameId == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _videoService.submitQuizAnswer(
        gameId: widget.promotion.gameId!,
        answer: _selectedAnswer!,
      );

      setState(() {
        _isCorrect = result['correct'] == true;
        _pointsEarned = result['points'] ?? 0;
        _showResult = true;
      });

      // Attendre 3 secondes puis fermer
      await Future.delayed(const Duration(seconds: 3));
      widget.onCompleted();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}')));
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F7FA), Color(0xFFFFFFFF)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _showResult ? _buildResultView() : _buildQuizView(),
      ),
    );
  }

  Widget _buildQuizView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.quiz, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Quiz Bonus',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Question
          Text(
            widget.promotion.question ?? 'Question non disponible',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Réponses
          ..._answers.map((answer) {
            final isSelected = _selectedAnswer == answer;
            return GestureDetector(
              onTap: () {
                if (!_isSubmitting) {
                  setState(() {
                    _selectedAnswer = answer;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        answer,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          // Bouton Valider
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedAnswer != null && !_isSubmitting
                  ? _submitAnswer
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Valider ma réponse',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône résultat
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isCorrect
                  ? const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEF5350), Color(0xFFC62828)],
                    ),
              boxShadow: [
                BoxShadow(
                  color: (_isCorrect ? Colors.green : Colors.red).withOpacity(
                    0.3,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _isCorrect ? Icons.check_circle : Icons.cancel,
              size: 60,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _isCorrect ? 'Bonne réponse !' : 'Mauvaise réponse',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),

          const SizedBox(height: 16),

          if (_isCorrect && _pointsEarned > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    '+$_pointsEarned points',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          const Text(
            'Fermeture automatique...',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
