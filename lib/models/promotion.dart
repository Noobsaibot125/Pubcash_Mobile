class Promotion {
  final int id;
  final String titre;
  final String? description;
  final String urlVideo;
  final String? thumbnailUrl;
  final int remunerationPack;
  final int duree;
  final String? gameType;

  Promotion({
    required this.id,
    required this.titre,
    this.description,
    required this.urlVideo,
    this.thumbnailUrl,
    required this.remunerationPack,
    required this.duree,
    this.gameType,
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
    );
  }
}
