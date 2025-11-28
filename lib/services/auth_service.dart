import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'api_service.dart';
import '../models/user.dart';
import '../utils/constants.dart';
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

  Future<bool> register(User user, String password) async {
    try {
      _setLoading(true);

      final data = user.toJson();
      data['mot_de_passe'] = password;

      // Nettoyage des champs nuls ou vides
      data.removeWhere(
        (key, value) => value == null || value.toString().isEmpty,
      );

      final response = await _apiService.post(
        AppConstants.registerEndpoint,
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

  // Connexion Classique
  Future<void> login(String email, String password) async {
    try {
      _setLoading(true);

      final response = await _apiService.post(
        AppConstants.loginEndpoint,
        data: {'identifier': email, 'password': password},
      );

      await _handleAuthResponse(response.data);
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Connexion Google
  Future<void> loginWithGoogle() async {
    try {
      _setLoading(true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final response = await _apiService.post(
          AppConstants.googleAuthEndpoint,
          data: {
            'accessToken': googleAuth.accessToken,
            // 'idToken': googleAuth.idToken, // Si nécessaire côté backend
          },
        );

        await _handleAuthResponse(response.data);
      }
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Connexion Facebook
  Future<void> loginWithFacebook() async {
    try {
      _setLoading(true);
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;

        final response = await _apiService.post(
          AppConstants.facebookAuthEndpoint,
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

  // Déconnexion
  Future<void> logout() async {
    await _secureStorage.delete(key: AppConstants.keyAccessToken);
    await _secureStorage.delete(key: AppConstants.keyRefreshToken);
    _apiService.clearAuthToken();
    _currentUser = null;
    _token = null;
    _requiresProfileCompletion = false;

    // Déconnexion sociale si nécessaire
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await FacebookAuth.instance.logOut();

    notifyListeners();
  }

  // Traitement de la réponse d'auth
 Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    print("🔍 Analyse de la réponse Auth: $data"); // Pour voir ce qui arrive vraiment

    // 1. SÉCURISATION TOTALE DES TOKENS (Convertit tout en String, même les objets)
    // On utilise ?.toString() pour éviter le crash si c'est un Map ou null
    final String accessToken = data['accessToken']?.toString() ?? '';
    final String refreshToken = data['refreshToken']?.toString() ?? '';

    if (accessToken.isEmpty) {
      throw Exception("Token d'accès manquant dans la réponse API");
    }

    // 2. Sauvegarde
    await _secureStorage.write(
      key: AppConstants.keyAccessToken,
      value: accessToken,
    );
    await _secureStorage.write(
      key: AppConstants.keyRefreshToken,
      value: refreshToken,
    );

    _token = accessToken;
    _apiService.setAuthToken(accessToken);

    // 3. Traitement de l'utilisateur
    if (data['user'] != null) {
      try {
        // On vérifie que 'user' est bien une Map avant de l'envoyer
        if (data['user'] is Map<String, dynamic>) {
           _currentUser = User.fromJson(data['user']);
        } else {
           print("⚠️ ATTENTION: data['user'] n'est pas un objet JSON valide");
        }
      } catch (e) {
        print("❌ Erreur parsing User: $e");
        // On ne rethrow pas ici pour ne pas bloquer le login si juste le profil plante
      }

      if (_currentUser != null && _currentUser!.isSocialUser && !isProfileComplete) {
        _requiresProfileCompletion = true;
        // Note: On ne throw pas forcément ici si on veut laisser l'utilisateur entrer
        // throw IncompleteProfileException(); 
      } else {
        _requiresProfileCompletion = false;
      }
    }

    notifyListeners();
}

  // Récupérer le profil complet de l'utilisateur
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final response = await _apiService.get('/user/profile');
      return response.data;
    } catch (e) {
      throw Exception('Erreur lors de la récupération du profil: $e');
    }
  }

  // Complétion de profil
  Future<void> completeProfile({
    required String commune,
    required String dateNaissance,
    required String contact,
    required String genre,
  }) async {
    try {
      _setLoading(true);

      final response = await _apiService.patch(
        '/auth/utilisateur/complete-profile',
        data: {
          'commune_choisie': commune,
          'date_naissance': dateNaissance,
          'contact': contact,
          'genre': genre,
        },
      );

      // Mise à jour du token et de l'utilisateur
      if (response.data['token'] != null) {
        await _secureStorage.write(
          key: AppConstants.keyAccessToken,
          value: response.data['token'],
        );
        _token = response.data['token'];
        _apiService.setAuthToken(_token!);
      }

      // Mettre à jour l'utilisateur localement
      if (response.data['user'] != null) {
        _currentUser = User.fromJson(response.data['user']);
        // Une fois complété, on met à jour l'état
        _requiresProfileCompletion = false;
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  bool get isProfileComplete {
    if (_currentUser == null) return false;

    // Si l'utilisateur n'est pas un utilisateur social (inscription normale),
    // son profil est déjà complet (tous les champs ont été remplis à l'inscription)
    if (!_currentUser!.isSocialUser) {
      return true;
    }

    // Pour les utilisateurs sociaux (Google/Facebook),
    // vérifier si les champs obligatoires sont présents
    return _currentUser!.commune != null &&
        _currentUser!.commune!.isNotEmpty &&
        _currentUser!.contact != null &&
        _currentUser!.contact!.isNotEmpty &&
        _currentUser!.dateNaissance != null &&
        _currentUser!.dateNaissance!.isNotEmpty &&
        _currentUser!.genre != null &&
        _currentUser!.genre!.isNotEmpty;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  init() {}
}
