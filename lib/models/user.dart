class User {
  final int? id;
  final String nomUtilisateur;
  final String email;
  final String? nom;
  final String? prenom;
  final String? commune;
  final String? ville;
  final String? dateNaissance;
  final String? contact;
  final String? genre;
  final String? photoUrl;
  final String? imageBackground;
  
  // Champs pour la logique sociale
  final String? idGoogle;
  final String? idFacebook;
  
  final String? codeParrainage;
  final int points;
  final double solde;
  final List<dynamic>? referrals;
  
  // Nouveau champ (optionnel mais utile vu que le backend l'envoie)
  final String? pushNotification;

  // ⚠️ IMPORTANT : Change ceci selon ton environnement
  // En local : "http://192.168.1.15:5000"
  // En production : "https://pub-cash.com"
  static const String baseUrl = "https://pub-cash.com";

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
    this.pushNotification,
  });

  // 👇 C'est cette propriété qui est utilisée dans profile_screen.dart
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

      // Gestion intelligente : backend envoie parfois 'commune_choisie', parfois 'commune'
      commune: _safeString(json['commune_choisie']) ?? _safeString(json['commune']),

      ville: _safeString(json['ville']),
      dateNaissance: _safeString(json['date_naissance']),
      contact: _safeString(json['contact']),
      genre: _safeString(json['genre']),

      // --- CONSTRUCTION DES URLS ---
      // Si l'URL commence par http, on la garde, sinon on construit le chemin complet
      photoUrl: _constructFullUrl(
        json['photo_profil'], 
        json['profile_image_url'], 
        'profile'
      ),
      
      imageBackground: _constructFullUrl(
        json['image_background'], 
        json['background_image_url'], 
        'background'
      ),
      // -----------------------------

      idGoogle: _safeString(json['id_google']),
      idFacebook: _safeString(json['id_facebook']),
      codeParrainage: _safeString(json['code_parrainage']),
      pushNotification: _safeString(json['push_notification']),

      points: _safeInt(json['points']),
      
      // Gère 'remuneration_utilisateur' ou 'solde'
      solde: _safeDouble(json['remuneration_utilisateur']) ?? 
             _safeDouble(json['solde']) ?? 0.0,

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
      'id_google': idGoogle,
      'id_facebook': idFacebook,
    };
  }

  // --- FONCTION UTILITAIRE POUR RECONSTRUIRE L'URL ---
  static String? _constructFullUrl(dynamic shortName, dynamic fullUrl, String folder) {
    // 1. Si on a déjà une URL complète qui vient de Facebook/Google ou du backend
    if (fullUrl != null && fullUrl.toString().startsWith('http')) {
      return fullUrl.toString();
    }
    // Cas spécial Facebook/Google renvoyés dans le champ court
    if (shortName != null && shortName.toString().startsWith('http')) {
      return shortName.toString();
    }
    
    // 2. Sinon, on récupère le nom du fichier (ex: image.jpg)
    String? filename = _safeString(shortName);
    
    // 3. On construit l'URL complète manuellement
    if (filename != null && filename.isNotEmpty) {
      // Sécurité pour les chemins Windows
      filename = filename.replaceAll('\\', '/');
      return "$baseUrl/uploads/$folder/$filename"; 
    }
    
    return null;
  }

  // --- HELPERS DE SÉCURITÉ (Évite les crashs sur null) ---
  static String? _safeString(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      if (value.toLowerCase() == 'null' || value.trim().isEmpty) return null;
      return value;
    }
    return value.toString();
  }

  static int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.toLowerCase() == 'null' || value.trim().isEmpty) return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      if (value.toLowerCase() == 'null' || value.trim().isEmpty) return 0.0;
      return double.tryParse(value);
    }
    return 0.0;
  }
}