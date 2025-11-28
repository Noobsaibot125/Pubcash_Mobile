import 'quiz.dart';

class Promotion {
  final int id;
  final String titre;
  final String? description;
  final String urlVideo;
  final String? thumbnailUrl;
  final int remunerationPack;
  final int duree;
  final String? gameType;
  final Quiz? quiz;

  Promotion({
    required this.id,
    required this.titre,
    this.description,
    required this.urlVideo,
    this.thumbnailUrl,
    required this.remunerationPack,
    required this.duree,
    this.gameType,
    this.quiz,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id'],
      titre: json['titre'] ?? '',
      description: json['description'],
      urlVideo: json['url_video'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      remunerationPack: json['remuneration_pack'] ?? 0,
      duree: json['duree'] ?? 0,
      gameType: json['game_type'],
      quiz: json['quiz'] != null ? Quiz.fromJson(json['quiz']) : null,
    );
  }

  // --- Helpers pour éviter les crashs de type ---

  /// Convertit n'importe quoi (String, Map, Int) en String ou null
  static String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    // Si c'est un objet (Map) ou une liste, on ne crash pas, on convertit en string
    return value.toString();
  }

  /// Convertit n'importe quoi en Int (ou 0 si échec)
  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
}