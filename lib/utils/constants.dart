// Constantes de l'application PubCash
class AppConstants {
  // API URLs
  static const String baseUrlDev = 'http://10.0.2.2:5000/api';
  static const String baseUrlProd = 'http://31.97.68.170/api';
  
  // Utiliser dev ou prod selon l'environnement
  static const String baseUrl = baseUrlDev;
  
  // Endpoints
  static const String registerEndpoint = '/auth/utilisateur/register';
  static const String loginEndpoint = '/auth/utilisateur/login';
  static const String googleAuthEndpoint = '/auth/google';
  static const String facebookAuthEndpoint = '/auth/facebook';
  static const String villesEndpoint = '/villes';
  static const String communesEndpoint = '/communes';
  
  // Storage Keys
  static const String keyAccessToken = 'accessToken';
  static const String keyRefreshToken = 'refreshToken';
  static const String keyUserId = 'userId';
  static const String keyUserRole = 'userRole';
  
  // Validation
  static const int minPasswordLength = 6;
}
