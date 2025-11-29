import 'package:flutter/material.dart';
import '../models/promotion.dart';
import '../utils/colors.dart';

class QuizDialog extends StatefulWidget {
  final Promotion promotion;
  final Function(bool success) onFinish;

  const QuizDialog({
    Key? key,
    required this.promotion,
    required this.onFinish,
  }) : super(key: key);

  @override
  State<QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<QuizDialog> {
  String? _selectedAnswer;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    // Si pas de réponses, on met des défauts pour éviter le crash
    final answers = widget.promotion.reponses ?? ["Oui", "Non"];

    return WillPopScope(
      onWillPop: () async => false, // Empêche de fermer sans répondre
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text(
                "Quiz Bonus",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Gagnez +${widget.promotion.pointsRecompense ?? 0} points !",
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
              const Divider(height: 30),

              // Question
              Text(
                widget.promotion.question ?? "Question mystère ?",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Réponses
              ...answers.map((answer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedAnswer == answer 
                          ? AppColors.primary.withOpacity(0.1) 
                          : Colors.white,
                      side: BorderSide(
                        color: _selectedAnswer == answer 
                            ? AppColors.primary 
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isSubmitting 
                        ? null 
                        : () => setState(() => _selectedAnswer = answer),
                    child: Text(
                      answer,
                      style: TextStyle(
                        color: _selectedAnswer == answer 
                            ? AppColors.primary 
                            : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )).toList(),

              const SizedBox(height: 20),

              // Bouton Valider
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: (_selectedAnswer == null || _isSubmitting)
                      ? null
                      : () => _submitAnswer(),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Valider ma réponse", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitAnswer() {
    // On passe la réponse au parent (VideoPlayerScreen) qui fera l'appel API
    // On pourrait le faire ici, mais pour garder la logique groupée on renvoie juste le choix
    widget.onFinish(_selectedAnswer == widget.promotion.bonneReponse);
  }
}