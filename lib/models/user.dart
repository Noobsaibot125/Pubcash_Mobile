class User {
  final int? id;
  final String nomUtilisateur;
  final String email;
  final String? nom; // Ajout
  final String? prenom; // Ajout
  final String? commune;
  final String? ville;
  final String? dateNaissance;
  final String? contact;
  final String? genre;
  final String? photoUrl;
  final String? imageBackground; // Ajout
  final String? idGoogle;
  final String? idFacebook;
  final String? codeParrainage;
  final int points;
  final double solde;
  final List<dynamic>? referrals; // Liste des filleuls

  User({
    this.id,
    required this.nomUtilisateur,
    required this.email,
    this.nom,
    this.prenom,
    this.photoUrl,
    this.imageBackground,
    this.commune,
    this.ville,
    this.dateNaissance,
    this.contact,
    this.genre,
    this.idGoogle,
    this.idFacebook,
    this.codeParrainage,
    this.points = 0,
    this.solde = 0.0,
    this.referrals,
  });

  bool get isSocialUser => 
      (idGoogle != null && idGoogle!.isNotEmpty) || 
      (idFacebook != null && idFacebook!.isNotEmpty);

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: int.tryParse(json['id']?.toString() ?? '0'),
      nomUtilisateur: json['nom_utilisateur']?.toString() ?? 'Utilisateur',
      email: json['email']?.toString() ?? '',
      nom: _safeString(json['nom']),
      prenom: _safeString(json['prenom']),
      commune: _safeString(json['commune_choisie']) ?? _safeString(json['commune']),
      ville: _safeString(json['ville']),
      dateNaissance: _safeString(json['date_naissance']),
      contact: _safeString(json['contact']),
      genre: _safeString(json['genre']),
      photoUrl: _safeString(json['photo_profil']) ?? _safeString(json['profile_image_url']),
      imageBackground: _safeString(json['image_background']) ?? _safeString(json['background_image_url']),
      idGoogle: _safeString(json['id_google']),
      idFacebook: _safeString(json['id_facebook']),
      codeParrainage: _safeString(json['code_parrainage']),
      points: _safeInt(json['points']),
      solde: _safeDouble(json['remuneration_utilisateur']) ?? _safeDouble(json['solde']) ?? 0.0,
      referrals: json['referrals'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom_utilisateur': nomUtilisateur,
      'email': email,
      'nom': nom,
      'prenom': prenom,
      'commune_choisie': commune,
      'ville': ville,
      'date_naissance': dateNaissance,
      'contact': contact,
      'genre': genre,
      'code_parrainage': codeParrainage,
    };
  }

  static String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return 0.0;
  }
}