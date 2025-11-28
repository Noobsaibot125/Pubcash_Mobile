class Ville {
  final int id;
  final String nom;
  
  Ville({
    required this.id,
    required this.nom,
  });
  
  factory Ville.fromJson(Map<String, dynamic> json) {
    return Ville(
      id: json['id'],
      nom: json['nom'],
    );
  }
}

class Commune {
  final int id;
  final String nom;
  final String ville;
  
  Commune({
    required this.id,
    required this.nom,
    required this.ville,
  });
  
  factory Commune.fromJson(Map<String, dynamic> json) {
    return Commune(
      id: json['id'],
      nom: json['nom'],
      ville: json['ville'],
    );
  }
}
