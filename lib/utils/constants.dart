// Constantes de l'application PubCash
class AppConstants {
  // API URLs
  static const String baseUrlDev = 'http://10.0.2.2:5000/api';
  
  // URL de PROD (Basée sur votre REACT_APP_API_URL)
  // C'est l'URL sécurisée (https) sans le port 5000 explicite, gérée par le serveur web
  static const String baseUrlProd = 'https://pub-cash.com/api';
  
  // --- CONFIGURATION ACTUELLE : PROD ---
  // On pointe la variable 'baseUrl' vers la prod
  static const String baseUrl = baseUrlProd;
  
  // Endpoints (Ceux qui marchaient dans votre ancien code)
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