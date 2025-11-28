class Game {
  final int id;
  final String nom;
  final String? description;
  final String lienJeu;
  final String? imageUrl;

  Game({
    required this.id,
    required this.nom,
    this.description,
    required this.lienJeu,
    this.imageUrl,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      nom: json['nom'],
      description: json['description'],
      lienJeu: json['lien_jeu'],
      imageUrl: json['image_url'],
    );
  }
}
