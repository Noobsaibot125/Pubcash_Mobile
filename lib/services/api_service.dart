import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class ApiService {
  final Dio _dio;
  // On crée une instance du stockage pour lire le token
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    // AJOUT DES INTERCEPTEURS (C'est ici que la magie opère)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. Avant d'envoyer la requête, on cherche le token dans le téléphone
          final token = await _secureStorage.read(key: AppConstants.keyAccessToken);
          
          // 2. Si on trouve un token, on l'ajoute aux headers
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            print('🔑 Token ajouté à la requête: ${options.path}');
          } else {
            print('⚠️ Aucun token trouvé pour: ${options.path}');
          }

          print('🚀 [${options.method}] ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ [${response.statusCode}] ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          print('❌ [${e.response?.statusCode}] ${e.requestOptions.path}');
          
          if (e.response?.data != null) {
             print('📦 Body Erreur: ${e.response?.data}');
          }

          if (e.response?.statusCode == 401) {
            print('🔐 Erreur 401: Token invalide ou expiré.');
            // Idéalement : Rediriger vers la page de connexion ici
          }
          
          return handler.next(e);
        },
      ),
    );
  }

  // GET Request
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(endpoint, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  // POST Request
  Future<Response> post(String endpoint, {dynamic data}) async {
    try {
      return await _dio.post(endpoint, data: data);
    } catch (e) {
      rethrow;
    }
  }

  // PATCH Request
  Future<Response> patch(String endpoint, {dynamic data}) async {
    try {
      return await _dio.patch(endpoint, data: data);
    } catch (e) {
      rethrow;
    }
  }

  // Plus besoin de setAuthToken manuel, l'intercepteur le fait tout seul !
  void setAuthToken(String token) {
    // On garde la méthode pour compatibilité, mais elle ne sert plus à grand chose
    // car on lit directement depuis le stockage.
  }

  void clearAuthToken() {
    // Logout géré par suppression du secure storage dans AuthService
  }
}