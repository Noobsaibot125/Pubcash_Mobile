class Game {
  final int id;
  final String type; // 'puzzle', 'quiz'
  final String titre;
  final String? imageUrl;
  final int pointsRecompense;
  final int? dureeLimite;
  final bool dejaJoue;

  Game({
    required this.id,
    required this.type,
    required this.titre,
    this.imageUrl,
    required this.pointsRecompense,
    this.dureeLimite,
    this.dejaJoue = false,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      type: json['type'] ?? 'puzzle',
      titre: json['titre'] ?? 'Jeu sans titre',
      imageUrl: json['image_url'],
      pointsRecompense: json['points_recompense'] ?? 0,
      dureeLimite: json['duree_limite'],
      dejaJoue: json['deja_joue'] == true || json['deja_joue'] == 1,
    );
  }
}
