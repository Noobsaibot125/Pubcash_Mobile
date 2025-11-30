class ApiConstants {
  // Base URL de production (celle qui fonctionne)
  static const String baseUrl = 'https://pub-cash.com/api';
  static const String apiUrl = '$baseUrl';

  // Endpoints Auth
  static const String login = '/auth/utilisateur/login';
  static const String register = '/auth/utilisateur/register';
  static const String googleAuth = '/auth/google';
  static const String facebookAuth = '/auth/facebook';
  static const String refreshToken = '/auth/refresh-token';

  // Endpoints User
  static const String userProfile = '/user/profile';
 static const String updateProfile = '/user/profile';
  static const String completeProfile = '/auth/utilisateur/complete-profile';
  static const String uploadProfileImage = '/user/upload-profile-image';

  // Endpoints Data
  static const String villes = '/villes';
  static const String communes = '/communes';

  // Endpoints Promotions/Videos
  static const String promotions = '/promotions';
  static const String userEarnings = '/promotions/utilisateur/gains';
  static const String userVideos = '/promotions/utilisateur/videos';

  // Endpoints Games
  static const String gamePoints = '/games/points';
  static const String gameWheel = '/games/wheel';
  static const String gameList = '/games/list';
  static const String gamePuzzleStart = '/games/puzzle/start';
  static const String gamePuzzleSubmit = '/games/puzzle/submit';

  // Endpoints Notifications
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount =
      '/notifications/non-lues/count';
  static const String notificationsMarkRead = '/notifications/:id/lire';
  static const String notificationsMarkAllRead = '/notifications/lire-toutes';
  static const String notificationsToken = '/notifications/token';

  // Headers
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
}
