import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'api_service.dart';
import '../models/user.dart';
import '../utils/api_constants.dart';
import '../utils/exceptions.dart';

class AuthService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _currentUser;
  bool _isLoading = false;
  String? _token;
  bool _requiresProfileCompletion = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  bool get requiresProfileCompletion => _requiresProfileCompletion;

  // --- 1. INSCRIPTION COMPLÈTE (Corrige pour matcher RegisterUser.js) ---
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

      // Construction manuelle du JSON pour être sûr des clés
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

      // Nettoyage des valeurs nulles
      data.removeWhere((key, value) => value == null || value.toString().isEmpty);

      final response = await _apiService.post(
        ApiConstants.register,
        data: data,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- 2. MISE A JOUR PROFIL SÉCURISÉE (Avec mot de passe actuel) ---
  Future<void> updateUserProfile({
    required String nom,
    required String prenom,
    required String nomUtilisateur,
    required String contact,
    required String currentPassword, // OBLIGATOIRE Côté Backend
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

      // Si pas de nouveau mot de passe, on retire la clé
      if (newPassword == null || newPassword.isEmpty) {
        data.remove('newPassword');
      }

      // Utilise PUT sur /api/user/profile (voir ApiConstants.updateProfile)
      await _apiService.put(
        ApiConstants.updateProfile, // Assure-toi que c'est '/auth/utilisateur/profile' ou '/user/profile' selon tes routes
        data: data,
      );

      // Recharger les données locales pour voir les modifs immédiatement
      await refreshUserProfile();

    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- 3. REFRESH PROFILE (Récupérer points, solde, filleuls) ---
  Future<void> refreshUserProfile() async {
    if (_token == null) return;

    try {
      // Appel à /user/profile
      final response = await _apiService.get(ApiConstants.userProfile);

      if (response.statusCode == 200 && response.data != null) {
        _currentUser = User.fromJson(response.data);
        notifyListeners();
        print("✅ Profil mis à jour: ${_currentUser?.nomUtilisateur} (${_currentUser?.points} pts)");
      }
    } catch (e) {
      print("⚠️ Impossible de rafraîchir le profil: $e");
    }
  }

  // --- 4. LOGIN CLASSIQUE ---
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

  // --- 5. SOCIAL LOGIN (Google) ---
  Future<void> loginWithGoogle() async {
    try {
      _setLoading(true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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

  // --- 6. SOCIAL LOGIN (Facebook) ---
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

  // --- 7. LOGOUT ---
  Future<void> logout() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    _currentUser = null;
    _token = null;
    _requiresProfileCompletion = false;

    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await FacebookAuth.instance.logOut();

    notifyListeners();
  }

  // --- 8. TRAITEMENT RÉPONSE AUTH ---
  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    print("🔍 Auth Response: $data");

    final String accessToken = data['accessToken']?.toString() ?? '';
    final String refreshToken = data['refreshToken']?.toString() ?? '';

    if (accessToken.isEmpty) {
      throw Exception("Token manquant");
    }

    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    _token = accessToken;

    if (data['user'] != null) {
      try {
        _currentUser = User.fromJson(data['user']);
      } catch (e) {
        print("❌ Erreur parsing User: $e");
      }

      // Vérification profile incomplet (Social Login)
      // On utilise le booléen 'profileCompleted' envoyé par le backend s'il existe, sinon logique locale
      bool isProfileCompletedBackend = data['profileCompleted'] == true;
      
      if (_currentUser != null && _currentUser!.isSocialUser && !isProfileCompletedBackend) {
         _requiresProfileCompletion = true;
      } else {
         _requiresProfileCompletion = false;
      }
    }
    notifyListeners();

    if (_requiresProfileCompletion) {
      throw IncompleteProfileException();
    }
  }

  // --- 9. COMPLETION PROFIL (Page dédiée) ---
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
        await _secureStorage.write(key: 'access_token', value: response.data['token']);
        _token = response.data['token'];
      }

      if (response.data['user'] != null) {
        _currentUser = User.fromJson(response.data['user']);
        _requiresProfileCompletion = false;
      }
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  Future<void> init() async {
    try {
      // 1. Lire le token stocké
      final accessToken = await _secureStorage.read(key: 'access_token');
      
      if (accessToken != null && accessToken.isNotEmpty) {
        _token = accessToken;
        // 2. Si on a un token, on essaie de charger le profil pour vérifier s'il est valide
        await refreshUserProfile();
        
        // Si refreshUserProfile a réussi, _currentUser sera rempli
        // Si le token est expiré, l'API renverra 401 et refreshUserProfile gère l'erreur
      }
    } catch (e) {
      print("Erreur lors de l'initialisation auth: $e");
      // En cas de pépin, on déconnecte pour être propre
      await logout();
    } finally {
      // On signale que le chargement initial est fini
      // (Si tu as une variable _isInitializing, c'est le moment de la passer à false)
      notifyListeners();
    }
  }
} // Fin de la classe AuthService
