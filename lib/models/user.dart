class User {
  final int? id;
  final String nomUtilisateur;
  final String email;
  final String? commune;
  final String? ville;
  final String? dateNaissance;
  final String? contact;
  final String? genre;
  final String? photoUrl;
  
  User({
    this.id,
    required this.nomUtilisateur,
    required this.email,
    this.photoUrl,
    this.commune,
    this.ville,
    this.dateNaissance,
    this.contact,
    this.genre,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nomUtilisateur: json['nom_utilisateur'],
      email: json['email'],
      commune: json['commune_choisie'] ?? json['commune'],
      ville: json['ville'],
      dateNaissance: json['date_naissance'],
      contact: json['contact'],
      genre: json['genre'],
      photoUrl: json['photo_url'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'nom_utilisateur': nomUtilisateur,
      'email': email,
      'commune': commune,
      'ville': ville,
      'date_naissance': dateNaissance,
      'contact': contact,
      'genre': genre,
      'photo_url': photoUrl,
    };
  }
}
