import 'dart:convert'; // Nécessaire pour jsonDecode

class Promotion {
  final int id;
  final String titre;
  final int idClient;
  final String? description;
  final String urlVideo;
  final String? thumbnailUrl;
  final int remunerationPack;
  final int duree;
  final String? clientName;   // Ajouté (nom_entreprise ou nom_utilisateur)
  final String? clientAvatar; // Ajouté (profile_image_url)
  // Champs Quiz / Game
  final int? gameId;
  final String? gameType;
  final String? question;
  final List<String>? reponses; // On va convertir la string JSON en Liste
  final String? bonneReponse;
  final int? pointsRecompense;

  Promotion({
    required this.id,
    required this.idClient,
    required this.titre,
    this.description,
    required this.urlVideo,
    this.thumbnailUrl,
    required this.remunerationPack,
    required this.duree,
    this.gameId,
    this.gameType,
    this.clientName,   // Ajouté
    this.clientAvatar, // Ajouté
    this.question,
    this.reponses,
    this.bonneReponse,
    this.pointsRecompense,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    // Gestion des réponses qui arrivent souvent sous forme de String JSON "[...]"
    List<String> parsedReponses = [];
    if (json['reponses'] != null) {
      try {
        if (json['reponses'] is String) {
          parsedReponses = List<String>.from(jsonDecode(json['reponses']));
        } else if (json['reponses'] is List) {
          parsedReponses = List<String>.from(json['reponses']);
        }
      } catch (e) {
        print("Erreur parsing reponses quiz: $e");
      }
    }

    return Promotion(
      id: json['id'],
      idClient: _safeInt(json['id_client']),
      titre: json['titre'] ?? '',
      description: json['description'],
      urlVideo: json['url_video'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      clientName: json['nom_entreprise'] ?? json['nom_utilisateur'] ?? 'Utilisateur',
      clientAvatar: json['profile_image_url'], // Assure-toi que c'est le bon nom de colonnefv
      remunerationPack: _safeInt(json['remuneration_pack']),
      duree: _safeInt(json['duree']),
      
      // Mapping des champs Game venant du LEFT JOIN dans PromotionController.js
      gameId: json['game_id'],
      gameType: json['game_type'],
      question: json['question'],
      reponses: parsedReponses.isNotEmpty ? parsedReponses : null,
      bonneReponse: json['bonne_reponse'],
      pointsRecompense: _safeInt(json['points_recompense']),
    );
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}