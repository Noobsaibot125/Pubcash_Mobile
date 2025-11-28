class Quiz {
  final int id;
  final String titre;
  final List<Question> questions;

  Quiz({required this.id, required this.titre, required this.questions});

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'],
      titre: json['titre'],
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q))
          .toList(),
    );
  }
}

class Question {
  final int id;
  final String texte;
  final List<Option> options;

  Question({required this.id, required this.texte, required this.options});

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      texte: json['texte'],
      options:
          (json['options'] as List).map((o) => Option.fromJson(o)).toList(),
    );
  }
}

class Option {
  final int id;
  final String texte;
  // Note: The backend doesn't send isCorrect, so we won't have it here.
  // The backend will handle the validation.

  Option({required this.id, required this.texte});

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      id: json['id'],
      texte: json['texte'],
    );
  }
}
