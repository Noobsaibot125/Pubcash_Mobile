import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'api_service.dart';
import '../models/user.dart';
import '../utils/constants.dart';

class AuthService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _currentUser;
  bool _isLoading = false;
  String? _token;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  // Initialisation au démarrage
  Future<void> init() async {
    _token = await _secureStorage.read(key: AppConstants.keyAccessToken);
    if (_token != null) {
      _apiService.setAuthToken(_token!);
      // Ici on pourrait récupérer le profil utilisateur si nécessaire
      // await fetchUserProfile();
    }
  }

  // Inscription
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
        data: {
          'identifier': email, // Backend attend 'identifier'
          'password': password, // Backend attend 'password'
        },
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

    // Déconnexion sociale si nécessaire
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await FacebookAuth.instance.logOut();

    notifyListeners();
  }

  // Traitement de la réponse d'auth
  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    final String accessToken = data['accessToken'];
    final String refreshToken = data['refreshToken'];

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

    // Si l'API renvoie l'utilisateur, on le stocke
    if (data['user'] != null) {
      _currentUser = User.fromJson(data['user']);
    }

    notifyListeners();
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

      // On met à jour l'utilisateur localement
      if (_currentUser != null) {
        // Idéalement, on devrait refetch le profil complet, mais on peut patcher localement pour l'instant
        // Ou on rappelle init() / fetchProfile()
        // Pour simplifier, on considère que si ça réussit, le profil est complet
        // On peut recharger le user depuis le token décodé ou un endpoint /me
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
    // Vérifie si les champs obligatoires sont présents
    return _currentUser!.commune != null &&
        _currentUser!.commune!.isNotEmpty &&
        _currentUser!.contact != null &&
        _currentUser!.contact!.isNotEmpty;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
