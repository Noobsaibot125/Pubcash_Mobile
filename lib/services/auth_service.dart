import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart'; // Nécessaire pour MediaType
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/user.dart';
import '../utils/api_constants.dart';
import 'notification_service.dart';
import '../utils/exceptions.dart';

class AuthService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Ton Web Client ID Google
  static const String _webClientId =
      "405007653561-9lbqs19rj6ib7kvch1nq841m6o4tiehs.apps.googleusercontent.com";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
    scopes: ['email', 'profile'],
  );

  // --- VARIABLES D'ÉTAT ---
  User? _currentUser;
  bool _isLoading = false;
  String? _token;
  bool _requiresProfileCompletion = false;

  // Verrou pour éviter les boucles de rafraîchissement infinies
  bool _isRefreshing = false;

  // Gestion de l'affichage du solde
  bool _showBalance = true;

  // --- GETTERS ---
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  bool get requiresProfileCompletion => _requiresProfileCompletion;
  bool get showBalance => _showBalance;

  // --- ACTIONS UI ---
  void toggleBalance() {
    _showBalance = !_showBalance;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // =========================================================
  // 1. INITIALISATION ET VÉRIFICATION
  // =========================================================

  Future<void> init() async {
    try {
      final accessToken = await _secureStorage.read(key: 'access_token');

      // TENTATIVE DE CHARGEMENT DU PROFIL EN CACHE (Optimistic UI)
      final cachedProfile = await _secureStorage.read(
        key: 'cached_user_profile',
      );
      if (cachedProfile != null) {
        try {
          _currentUser = User.fromJson(jsonDecode(cachedProfile));
          _checkIfProfileIsComplete();
          print("✅ Profil chargé depuis le cache");
          notifyListeners();
        } catch (e) {
          print("⚠️ Erreur lecture cache profil: $e");
        }
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        _token = accessToken;
        // On tente de récupérer les infos fraîches
        await refreshUserProfile();
      }
    } catch (e) {
      print("⚠️ Erreur init auth: $e");
      // On ne déconnecte pas ici, peut-être juste une erreur réseau
    } finally {
      notifyListeners();
    }
  }

  // =========================================================
  // 2. AUTHENTIFICATION (LOGIN / REGISTER)
  // =========================================================

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
      // Nettoyage des valeurs nulles ou vides
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

  // =========================================================
  // 3. GESTION DU PROFIL
  // =========================================================

  Future<void> refreshUserProfile() async {
    if (_token == null) return;
    if (_isRefreshing) return; // Sécurité anti-boucle

    try {
      final response = await _apiService.get(ApiConstants.userProfile);

      if (response.statusCode == 200 && response.data != null) {
        _currentUser = User.fromJson(response.data);

        // MISE EN CACHE DU PROFIL
        await _secureStorage.write(
          key: 'cached_user_profile',
          value: jsonEncode(response.data),
        );

        _checkIfProfileIsComplete();
        notifyListeners();
      }
    } catch (e) {
      print("⚠️ Erreur refresh profil: $e");

      // DÉTECTION ROBUSTE DU 401 (TOKEN EXPIRÉ)
      bool isUnauthorized = false;
      if (e is DioException && e.response?.statusCode == 401) {
        isUnauthorized = true;
      } else if (e.toString().contains('401')) {
        isUnauthorized = true;
      }

      if (isUnauthorized) {
        print("🔐 Token expiré, tentative de renouvellement...");
        _isRefreshing = true;

        bool refreshed = await tryRefreshToken();

        _isRefreshing = false;

        if (refreshed) {
          // Si refresh réussi, on réessaie de charger le profil
          await refreshUserProfile();
        } else {
          // Si refresh échoué, là seulement on déconnecte
          print("❌ Refresh échoué, déconnexion.");
          await logout();
        }
      }
    }
  }

  // Mise à jour des informations (AVEC CORRECTION 401)
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
      // On retire le nouveau mot de passe s'il est vide
      if (newPassword == null || newPassword.isEmpty) {
        data.remove('newPassword');
      }

      await _apiService.put(ApiConstants.updateProfile, data: data);

      // Mise à jour réussie, on rafraîchit les données locales
      await refreshUserProfile();
    } catch (e) {
      // IMPORTANT : On laisse l'erreur remonter (rethrow)
      // C'est l'UI (EditInfoScreen) qui gérera le message "Mot de passe incorrect"
      // On NE TENTE PAS de refresh token ici car 401 ici = mauvais mot de passe
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> uploadProfileImage(File imageFile) async {
    try {
      _setLoading(true);
      String fileName = imageFile.path.split('/').last;
      String subType = fileName.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';

      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: MediaType('image', subType),
        ),
      });

      await _apiService.post(ApiConstants.uploadProfileImage, data: formData);
      await refreshUserProfile();
    } catch (e) {
      print("Erreur upload image: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

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

      await refreshUserProfile();
      _requiresProfileCompletion = false;
      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _checkIfProfileIsComplete() {
    if (_currentUser == null) return;

    // Seuls les utilisateurs sociaux peuvent avoir un profil incomplet
    if (!_currentUser!.isSocialUser) {
      _requiresProfileCompletion = false;
      return;
    }

    bool missingData =
        (_currentUser!.commune == null || _currentUser!.commune!.isEmpty) ||
        (_currentUser!.dateNaissance == null ||
            _currentUser!.dateNaissance!.isEmpty) ||
        (_currentUser!.contact == null || _currentUser!.contact!.isEmpty);

    _requiresProfileCompletion = missingData;
  }

  // =========================================================
  // 4. LOGIQUE TOKEN & LOGOUT
  // =========================================================

  Future<bool> tryRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      // On utilise une instance Dio brute pour éviter les intercepteurs
      final dio = Dio();

      // Configuration des headers (Important pour Node.js/Express)
      dio.options.headers['Content-Type'] = 'application/json';
      dio.options.headers['Accept'] = 'application/json';

      final response = await dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
        data: {'token': refreshToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newAccessToken = response.data['accessToken'];
        final newRefreshToken = response.data['refreshToken'];

        if (newAccessToken != null) {
          await _secureStorage.write(
            key: 'access_token',
            value: newAccessToken,
          );
          _token = newAccessToken;

          if (newRefreshToken != null) {
            await _secureStorage.write(
              key: 'refresh_token',
              value: newRefreshToken,
            );
          }
          print("✅ Token rafraîchi avec succès !");
          return true;
        }
      }
    } catch (e) {
      print("⚠️ Échec du refresh token: $e");
    }
    return false;
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await _apiService.post('/auth/logout');
      }
    } catch (e) {
      print("Erreur logout backend: $e");
    } finally {
      // Nettoyage complet
      await _secureStorage.delete(key: 'access_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'cached_user_profile');
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

  // =========================================================
  // 5. MOT DE PASSE OUBLIÉ
  // =========================================================

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

  Future<void> verifyResetCode(String email, String code) async {
    try {
      _setLoading(true);
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

  // =========================================================
  // 6. HELPERS
  // =========================================================

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

    if (data['profileCompleted'] == false) {
      _requiresProfileCompletion = true;
    } else {
      _checkIfProfileIsComplete();
    }

    notifyListeners();

    // Initialisation des notifications une fois connecté
    print("🔔 Initialisation OneSignal...");
    NotificationService().initialiser();

    if (_requiresProfileCompletion) {
      throw IncompleteProfileException();
    }
  }

  static String getErrorMessage(dynamic error) {
    if (error is DioException && error.response?.data != null) {
      final data = error.response?.data;
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
    }
    return error.toString().replaceAll('Exception:', '').trim();
  }
}
