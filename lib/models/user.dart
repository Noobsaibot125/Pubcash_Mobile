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
  
  final String? photoUrl;
  final String? idGoogle;
  final String? idFacebook;

  User({
    this.id,
    required this.nomUtilisateur,
    required this.email,
    this.photoUrl,
    this.photoUrl,
    this.commune,
    this.ville,
    this.dateNaissance,
    this.contact,
    this.genre,
    this.idGoogle,
    this.idFacebook,
  });

  bool get isSocialUser => idGoogle != null || idFacebook != null;

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
      photoUrl: json['photo_profil'],
      // SÉCURITÉ 1 : Conversion forcée en int pour l'ID
      id: int.tryParse(json['id']?.toString() ?? '0'),

      // SÉCURITÉ 2 : Gestion des champs TEXTE obligatoires
      // Si l'API renvoie null, on met une chaine vide pour éviter le crash
      nomUtilisateur: json['nom_utilisateur']?.toString() ?? 'Utilisateur',
      email: json['email']?.toString() ?? '',

      // SÉCURITÉ 3 : LE CŒUR DU PROBLÈME (Map vs String)
      // On utilise .toString() partout. Si 'commune' est un objet {id:1, nom:...}, 
      // cela deviendra une String "{...}" au lieu de faire planter l'app.
      commune: _safeString(json['commune_choisie']) ?? _safeString(json['commune']),
      ville: _safeString(json['ville']),
      
      dateNaissance: _safeString(json['date_naissance']),
      contact: _safeString(json['contact']),
      genre: _safeString(json['genre']),
      
      // Gestion de la photo (SQL: photo_profil -> Dart: photoUrl)
      photoUrl: _safeString(json['photo_profil']) ?? _safeString(json['photo_url']),
      
      idGoogle: _safeString(json['id_google']),
      idFacebook: _safeString(json['id_facebook']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // J'ai ajouté l'ID au toJson, utile pour les updates
      'nom_utilisateur': nomUtilisateur,
      'email': email,
      'commune_choisie': commune, // Aligné avec ta base de données
      'ville': ville,
      'date_naissance': dateNaissance,
      'contact': contact,
      'genre': genre,
      'photo_profil': photoUrl,
      'photo_profil': photoUrl,
      'id_google': idGoogle,
      'id_facebook': idFacebook,
    };
  }

  // --- Fonction utilitaire pour éviter l'erreur rouge ---
  // Cette fonction transforme n'importe quoi (Objet, Liste, Int) en String
  // ou renvoie null si c'est vide.
  static String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}