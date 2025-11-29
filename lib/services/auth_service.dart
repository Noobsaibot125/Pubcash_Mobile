import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../models/user.dart';
import '../utils/api_constants.dart';
import '../utils/exceptions.dart';

class AuthService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Ton Web Client ID
  static const String _webClientId =
      "405007653561-9lbqs19rj6ib7kvch1nq841m6o4tiehs.apps.googleusercontent.com";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  User? _currentUser;
  bool _isLoading = false;
  String? _token;
  bool _requiresProfileCompletion = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  bool get requiresProfileCompletion => _requiresProfileCompletion;

  // === INITIALISATION ===
  Future<void> init() async {
    try {
      final accessToken = await _secureStorage.read(key: 'access_token');
      if (accessToken != null && accessToken.isNotEmpty) {
        _token = accessToken;
        await refreshUserProfile();
      }
    } catch (e) {
      print("Erreur init auth: $e");
      await logout();
    } finally {
      notifyListeners();
    }
  }

  // --- 1. INSCRIPTION ---
  Future<bool> register({
    required String nomUtilisateur,
    required String email,
    required String password,
    required String ville,
    required String commune,
    required String dateNaissance,
    String? contact,
    String? genre,
    String? codeParrainage,
  }) async {
    try {
      _setLoading(true);
      final data = {
        'nom_utilisateur': nomUtilisateur,
        'email': email,
        'mot_de_passe': password,
        'ville': ville,
        'commune': commune,
        'date_naissance': dateNaissance,
        'contact': contact,
        'genre': genre,
        'code_parrainage': codeParrainage,
      };
      data.removeWhere(
        (key, value) => value == null || value.toString().isEmpty,
      );

      final response = await _apiService.post(
        ApiConstants.register,
        data: data,
      );
      return (response.statusCode == 201 || response.statusCode == 200);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- 2. MISE A JOUR PROFIL ---
  Future<void> updateUserProfile({
    required String nom,
    required String prenom,
    required String nomUtilisateur,
    required String contact,
    required String currentPassword,
    String? newPassword,
  }) async {
    try {
      _setLoading(true);
      final data = {
        'nom': nom,
        'prenom': prenom,
        'nom_utilisateur': nomUtilisateur,
        'contact': contact,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      };
      if (newPassword == null || newPassword.isEmpty)
        data.remove('newPassword');

      await _apiService.put(ApiConstants.updateProfile, data: data);
      await refreshUserProfile();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- 2.1 UPLOAD IMAGE PROFIL ---
  Future<void> uploadProfileImage(File imageFile) async { // Utilise File au lieu de dynamic
    try {
      _setLoading(true);

      String fileName = imageFile.path.split('/').last;
      
      // Déterminer l'extension pour aider le backend
      // Si c'est un png, on dit 'image/png', sinon 'image/jpeg' par défaut
      String subType = fileName.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';

      FormData formData = FormData.fromMap({
        // "file" est bien la clé attendue par ton backend (multer.single('file'))
        "file": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          // IMPORTANT : On force le type MIME pour passer le filtre du backend
          contentType: MediaType('image', subType), 
        ),
      });

      // On envoie la requête
      await _apiService.post(ApiConstants.uploadProfileImage, data: formData);
      
      // On rafraîchit le profil immédiatement
      await refreshUserProfile(); 
      
    } catch (e) {
      print("Erreur upload image: $e"); // Log pour le debug
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- 3. REFRESH PROFILE ---
  Future<void> refreshUserProfile() async {
    if (_token == null) return;

    try {
      final response = await _apiService.get(ApiConstants.userProfile);

      if (response.statusCode == 200 && response.data != null) {
        _currentUser = User.fromJson(response.data);

        // VÉRIFICATION OBLIGATOIRE ICI
        _checkIfProfileIsComplete();

        notifyListeners();
      }
    } catch (e) {
      print("⚠️ Erreur refresh profil: $e");
      if (e.toString().contains('401')) {
        print("🔐 Token expiré, déconnexion...");
        await logout();
      }
    }
  }

  // --- LOGIQUE INTERNE DE VÉRIFICATION ---
  void _checkIfProfileIsComplete() {
    if (_currentUser == null) return;

    // CORRECTION : On ne vérifie QUE si c'est un utilisateur social
    // Les utilisateurs classiques ont déjà rempli ces infos à l'inscription
    if (!_currentUser!.isSocialUser) {
      _requiresProfileCompletion = false;
      return;
    }

    // DEBUG : Voir ce que Flutter reçoit vraiment
    print("🔍 CHECK PROFILE DATA:");
    print(" - Commune: '${_currentUser!.commune}'");
    print(" - Date: '${_currentUser!.dateNaissance}'");
    print(" - Contact: '${_currentUser!.contact}'");

    // On vérifie si les champs critiques sont vides
    bool missingData =
        (_currentUser!.commune == null || _currentUser!.commune!.isEmpty) ||
        (_currentUser!.dateNaissance == null ||
            _currentUser!.dateNaissance!.isEmpty) ||
        (_currentUser!.contact == null || _currentUser!.contact!.isEmpty);

    if (missingData) {
      print("⚠️ PROFIL CONSIDÉRÉ COMME INCOMPLET");
      _requiresProfileCompletion = true;
    } else {
      print("✅ PROFIL COMPLET");
      _requiresProfileCompletion = false;
    }
  }

  // --- 4. LOGIN ---
  Future<void> login(String email, String password) async {
    try {
      _setLoading(true);
      final response = await _apiService.post(
        ApiConstants.login,
        data: {'identifier': email, 'password': password},
      );
      await _handleAuthResponse(response.data);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- 5. SOCIAL LOGIN ---
  Future<void> loginWithGoogle() async {
    try {
      _setLoading(true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final response = await _apiService.post(
          ApiConstants.googleAuth,
          data: {'accessToken': googleAuth.accessToken},
        );
        await _handleAuthResponse(response.data);
      }
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginWithFacebook() async {
    try {
      _setLoading(true);
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final response = await _apiService.post(
          ApiConstants.facebookAuth,
          data: {'accessToken': accessToken.token},
        );
        await _handleAuthResponse(response.data);
      }
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- 6. LOGOUT ---
  Future<void> logout() async {
    try {
      // 1. Appeler le backend pour invalider le refresh token (Si le token existe encore)
      if (_token != null) {
        await _apiService.post('/auth/logout');
      }
    } catch (e) {
      print("Erreur logout backend (non bloquant): $e");
    } finally {
      // 2. Nettoyage local
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
      _currentUser = null;
      _token = null;
      _requiresProfileCompletion = false;

      try {
        await _googleSignIn.signOut();
        await FacebookAuth.instance.logOut();
      } catch (e) {
        print("Erreur logout social: $e");
      }

      notifyListeners();
    }
  }

  // --- MOT DE PASSE OUBLIÉ (NOUVEAU) ---

  // Étape 1 : Envoyer l'email
  Future<void> forgotPassword(String email) async {
    try {
      _setLoading(true);
      await _apiService.post('/auth/forgot-password', data: {'email': email});
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Étape 2 : Vérifier le code
  Future<void> verifyResetCode(String email, String code) async {
    try {
      _setLoading(true);
      // Nettoyage du code (espaces) comme en React
      final cleanCode = code.replaceAll(' ', '');
      await _apiService.post(
        '/auth/verify-reset-code',
        data: {'email': email, 'resetCode': cleanCode},
      );
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Étape 3 : Réinitialiser
  Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      _setLoading(true);
      final cleanCode = code.replaceAll(' ', '');
      await _apiService.post(
        '/auth/reset-password',
        data: {
          'email': email,
          'resetCode': cleanCode,
          'newPassword': newPassword,
        },
      );
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- HELPER POUR LES ERREURS ---
  // Utilise ceci dans tes UI pour afficher le message du backend
  static String getErrorMessage(dynamic error) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
    }
    return error.toString().replaceAll('Exception:', '').trim();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // --- 7. TRAITEMENT RÉPONSE AUTH ---
  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    final String accessToken = data['accessToken']?.toString() ?? '';
    final String refreshToken = data['refreshToken']?.toString() ?? '';

    if (accessToken.isEmpty) throw Exception("Token manquant");

    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    _token = accessToken;

    if (data['user'] != null) {
      try {
        _currentUser = User.fromJson(data['user']);
      } catch (e) {
        print("❌ Erreur parsing User: $e");
      }
    }

    // CORRECTION ICI : On utilise le flag backend OU notre vérification manuelle
    if (data['profileCompleted'] == false) {
      _requiresProfileCompletion = true;
    } else {
      _checkIfProfileIsComplete(); // Double sécurité
    }

    notifyListeners();

    if (_requiresProfileCompletion) {
      throw IncompleteProfileException();
    }
  }

  // --- 8. COMPLETION PROFIL ---
  Future<void> completeProfile({
    required String commune,
    required String dateNaissance,
    required String contact,
    required String genre,
  }) async {
    try {
      _setLoading(true);
      final response = await _apiService.patch(
        ApiConstants.completeProfile,
        data: {
          'commune_choisie': commune,
          'date_naissance': dateNaissance,
          'contact': contact,
          'genre': genre,
        },
      );

      if (response.data['token'] != null) {
        await _secureStorage.write(
          key: 'access_token',
          value: response.data['token'],
        );
        _token = response.data['token'];
      }

      // Recharger l'utilisateur complet pour confirmer
      await refreshUserProfile();

      // On force le flag à faux pour sortir de l'écran
      _requiresProfileCompletion = false;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
