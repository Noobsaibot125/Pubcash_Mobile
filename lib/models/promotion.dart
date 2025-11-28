import 'dart:convert';

class Promotion {
  final int id;
  final String titre;
  final String? description;
  final String urlVideo;
  final String? thumbnailUrl;
  final int remunerationPack;
  final int duree;
  final String? gameType;
  final int? gameId;
  final String? question;
  final String? reponses;
  final String? bonneReponse;
  final int? pointsRecompense;

  Promotion({
    required this.id,
    required this.titre,
    this.description,
    required this.urlVideo,
    this.thumbnailUrl,
    required this.remunerationPack,
    required this.duree,
    this.gameType,
    this.gameId,
    this.question,
    this.reponses,
    this.bonneReponse,
    this.pointsRecompense,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: _safeInt(json['id']),
      // Utilisation de _safeString pour éviter le crash "Map is not String"
      titre: _safeString(json['titre']) ?? 'Sans titre',
      description: _safeString(json['description']),
      urlVideo: _safeString(json['url_video']) ?? '',
      thumbnailUrl: _safeString(json['thumbnail_url']),
      remunerationPack: _safeInt(json['remuneration_pack']),
      duree: _safeInt(json['duree']),
      // Gestion des champs liés aux jeux (qui sont souvent des objets imbriqués)
      gameType: _safeString(json['game_type']),
      gameId: _safeInt(json['game_id']),
      question: _safeString(json['question']),
      
      // Logique spéciale pour les réponses (JSON string ou Objet)
      reponses: json['reponses'] is String
          ? json['reponses']
          : (json['reponses'] != null ? jsonEncode(json['reponses']) : null),
          
      bonneReponse: _safeString(json['bonne_reponse']),
      pointsRecompense: _safeInt(json['points_recompense']),
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