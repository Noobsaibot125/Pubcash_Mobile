import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/api_constants.dart';
// Import pour pouvoir rediriger l'utilisateur si besoin (optionnel selon ton architecture)
import '../main.dart'; 

class ApiService {
  // 1. SINGLETON : On s'assure qu'il n'y a qu'une seule instance de ApiService
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }

  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

 // Constructeur privé
  ApiService._internal() {
    
    // 👇 AJOUTE CETTE LIGNE POUR VÉRIFIER DANS LA CONSOLE 👇
    print('🚨 [ApiService] Démarrage avec URL : ${ApiConstants.baseUrl}');

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl, // Il prendra la valeur dynamique
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // AJOUT DES INTERCEPTEURS
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Lecture du token
          // Utilise une constante pour éviter les fautes de frappe !
          final token = await _secureStorage.read(key: 'access_token'); 

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            // print('🔑 Token ajouté'); // Décommente pour débugger uniquement
          }
          
          // print('🚀 [${options.method}] ${options.path}');
          return handler.next(options);
        },
        
        onResponse: (response, handler) {
          // print('✅ [${response.statusCode}] ${response.requestOptions.path}');
          return handler.next(response);
        },
        
        onError: (DioException e, handler) async {
          print('❌ [${e.response?.statusCode}] ${e.requestOptions.path}');

          // GESTION ERREUR 401 (Non autorisé / Token expiré)
          if (e.response?.statusCode == 401) {
            print('🔐 Session expirée. Nettoyage du token...');
            
            // 1. On supprime le token incorrect
            await _secureStorage.delete(key: 'access_token');
            
            // 2. (Optionnel) Ici tu pourrais forcer la déconnexion et renvoyer vers Login
            // navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
          }

          return handler.next(e);
        },
      ),
    );
  }

  // --- MÉTHODES HTTP ---

  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(endpoint, queryParameters: queryParameters);
  }

  Future<Response> post(String endpoint, {dynamic data}) async {
    return await _dio.post(endpoint, data: data);
  }

  Future<Response> patch(String endpoint, {dynamic data}) async {
    return await _dio.patch(endpoint, data: data);
  }

  Future<Response> put(String endpoint, {dynamic data}) async {
    return await _dio.put(endpoint, data: data);
  }

  Future<Response> delete(String endpoint) async {
    return await _dio.delete(endpoint);
  }
  
  // Utile pour l'upload d'images (Multipart)
  Future<Response> postFormData(String endpoint, FormData data) async {
    return await _dio.post(endpoint, data: data);
  }
}