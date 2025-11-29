import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/api_constants.dart';

class ApiService {
  final Dio _dio;
  // On crée une instance du stockage pour lire le token
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  ApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
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
          final token = await _secureStorage.read(
            key: 'access_token',
          ); // TODO: Use constant for key

          // 2. Si on trouve un token, on l'ajoute aux headers
          if (token != null && token.isNotEmpty) {
            options.headers[ApiConstants.authHeader] =
                '${ApiConstants.bearerPrefix}$token';
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
            // TODO: Implement refresh token logic here
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
    return await _dio.get(endpoint, queryParameters: queryParameters);
  }

  // POST Request
  Future<Response> post(String endpoint, {dynamic data}) async {
    return await _dio.post(endpoint, data: data);
  }

  // PATCH Request
  Future<Response> patch(String endpoint, {dynamic data}) async {
    return await _dio.patch(endpoint, data: data);
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    return await _dio.put(endpoint, data: data);
  }

  Future<Response> delete(String endpoint) async {
    return await _dio.delete(endpoint);
  }
}
