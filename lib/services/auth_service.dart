import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart'; // Nécessaire pour MediaType
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
  Map<String, dynamic>? _pendingSocialData;

  // Verrou pour éviter les boucles de rafraîchissement infinies
  bool _isRefreshing = false;

  // Gestion de l'affichage du solde
  bool _showBalance = true;

  // --- GETTERS ---
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  bool get requiresProfileCompletion => _requiresProfileCompletion;
  Map<String, dynamic>? get pendingSocialData => _pendingSocialData;
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

      // --- CORRECTION MAJEURE ICI ---
      // On force la déconnexion locale d'abord.
      // Cela oblige Google à ré-afficher la fenêtre de choix de compte
      // même si l'utilisateur avait déjà cliqué avant.
      await _googleSignIn.signOut();
      // -----------------------------

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('GOOGLE_CANCELED');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final response = await _apiService.post(
        ApiConstants.googleAuth,
        data: {'accessToken': googleAuth.accessToken},
      );
      await _handleAuthResponse(response.data);
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data as Map;
        if (data.containsKey('message')) {
          // Si le backend renvoie "Compte bloqué", on lève l'exception ici
          throw Exception(data['message']);
        }
      }
      throw Exception("Erreur de connexion avec Google.");
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginWithApple() async {
    try {
      _setLoading(true);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final response = await _apiService.post(
        ApiConstants.appleAuth,
        data: {
          'identityToken': credential.identityToken,
          'authorizationCode': credential.authorizationCode,
          'givenName': credential.givenName,
          'familyName': credential.familyName,
          'email': credential.email,
        },
      );
      await _handleAuthResponse(response.data);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('APPLE_CANCELED');
      }
      throw Exception('Erreur connexion Apple: ${e.message}');
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map) {
        final data = e.response!.data as Map;
        if (data.containsKey('message')) {
          throw Exception(data['message']);
        }
      }
      throw Exception("Erreur de connexion avec Apple.");
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
    if (_isRefreshing) return;

    try {
      final response = await _apiService.get(ApiConstants.userProfile);

      if (response.statusCode == 200 && response.data != null) {
        _currentUser = User.fromJson(response.data);
        await _secureStorage.write(
          key: 'cached_user_profile',
          value: jsonEncode(response.data),
        );
        _checkIfProfileIsComplete();
        notifyListeners();
      }
    } catch (e) {
      print("⚠️ Erreur refresh profil: $e");

      // --- ADD THIS BLOCK ---
      if (e is DioException) {
        // If we get a 403 Forbidden, it likely means the account is blocked/disabled
        if (e.response?.statusCode == 403) {
          print("⛔ Compte bloqué ou désactivé détecté. Déconnexion forcée.");
          await logout(); // This clears tokens and notifies listeners (which should redirect to login)
          return;
        }
      }
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
        // Apple Sign-In doesn't require explicit logout
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

  Future<void> registerSocial({
    required String commune,
    required String dateNaissance,
    required String contact,
    required String genre,
    String? codeParrainage,
  }) async {
    try {
      if (_pendingSocialData == null) {
        throw Exception("Données sociales manquantes.");
      }

      _setLoading(true);

      final response = await _apiService.post(
        ApiConstants.socialRegister,
        data: {
          'socialData': _pendingSocialData,
          'commune_choisie': commune,
          'date_naissance': dateNaissance,
          'contact': contact,
          'genre': genre,
          'code_parrainage': codeParrainage,
          'push_notification': await NotificationService().getToken(),
        },
      );

      await _handleAuthResponse(response.data);
      _pendingSocialData = null;
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    // 0. GESTION DU NOUVEL UTILISATEUR SOCIAL (Logique Atomique)
    if (data['isNewUser'] == true && data['socialData'] != null) {
      _pendingSocialData = data['socialData'];
      _requiresProfileCompletion = true;
      notifyListeners();
      throw IncompleteProfileException();
    }

    final String accessToken = data['accessToken']?.toString() ?? '';
    final String refreshToken = data['refreshToken']?.toString() ?? '';

    if (accessToken.isEmpty) throw Exception("Token manquant");

    // 1. Sauvegarde des tokens
    await _secureStorage.write(key: 'access_token', value: accessToken);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    _token = accessToken;

    // 2. Parsing de l'utilisateur
    if (data['user'] != null) {
      try {
        _currentUser = User.fromJson(data['user']);
      } catch (e) {
        print("❌ Erreur parsing User: $e");
      }
    }

    // 3. RECUPERATION DU FLAG BACKEND (C'est la correction clé)
    // Ton backend envoie "profileCompleted: true/false". On s'y fie à 100%.
    bool serverSaysProfileComplete = true;
    if (data.containsKey('profileCompleted')) {
      serverSaysProfileComplete = data['profileCompleted'];
    } else {
      // Fallback : si le backend ne l'envoie pas (ex: login classique), on vérifie manuellement
      _checkIfProfileIsComplete();
      serverSaysProfileComplete = !_requiresProfileCompletion;
    }

    notifyListeners();

    // 4. Initialisation OneSignal
    print("🔔 Initialisation OneSignal...");
    try {
      NotificationService().initialiser();
    } catch (e) {
      print("Erreur OneSignal init: $e");
    }

    // 5. Mise à jour du profil complet en arrière-plan (pour être sûr d'avoir les dernières infos)
    // On ne 'await' pas ici pour ne pas bloquer la navigation si le réseau est lent,
    // sauf si c'est critique pour vous.
    refreshUserProfile().catchError(
      (e) => print("⚠️ Erreur refresh background: $e"),
    );

    // 6. GESTION DE LA REDIRECTION
    if (!serverSaysProfileComplete) {
      _requiresProfileCompletion = true;
      throw IncompleteProfileException(); // Ceci déclenchera la navigation vers CompleteSocialProfile
    } else {
      _requiresProfileCompletion = false;
    }
  }

  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return "Le délai de connexion a expiré. Veuillez vérifier votre connexion internet.";
      }

      if (error.type == DioExceptionType.connectionError ||
          error.error is SocketException) {
        return "Impossible de se connecter au serveur. Vérifiez que vous êtes bien connecté à Internet.";
      }

      if (error.response?.data != null) {
        final data = error.response?.data;
        if (data is Map && data.containsKey('message')) {
          return data['message'];
        }
      }
    }

    final String msg = error.toString().toLowerCase();
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network_error')) {
      return "Erreur réseau : Veuillez vérifier votre connexion internet.";
    }

    return error.toString().replaceAll('Exception:', '').trim();
  }
  // =========================================================
  // 7. SUPPRESSION DE COMPTE
  // =========================================================

  Future<void> deleteAccount({
    String? password,
    required String authProvider,
  }) async {
    try {
      _setLoading(true);

      if (_currentUser == null || _currentUser!.id == null) {
        throw Exception("Utilisateur non identifié");
      }

      await _apiService.post(
        '/auth/utilisateur/delete-account',
        data: {
          'id': _currentUser!.id,
          'password': password,
          'authProvider': authProvider,
        },
      );
    } catch (e) {
      print("Erreur suppression compte: $e");

      // --- GESTION D'ERREUR AMÉLIORÉE ---
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          // C'est ici qu'on transforme l'erreur technique en message utilisateur
          throw Exception("Mot de passe incorrect.");
        } else if (e.response?.data != null && e.response?.data is Map) {
          // On récupère le message du backend s'il existe (ex: "Utilisateur introuvable")
          throw Exception(
            e.response?.data['message'] ?? "Erreur lors de la suppression.",
          );
        }
      }
      // ----------------------------------

      rethrow; // Relance l'exception propre pour l'afficher dans le SnackBar
    } finally {
      _setLoading(false);
    }
  }
}
