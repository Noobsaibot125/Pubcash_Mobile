import 'package:flutter/foundation.dart';

class ApiConstants {
  // ==============================================================================
  // 🎛️ INTERRUPTEUR DE TEST
  // ==============================================================================

  // METS CECI SUR 'true' POUR TRAVAILLER EN LOCAL
  // METS CECI SUR 'false' POUR TESTER LA VERSION EN LIGNE (MÊME EN DEBUG)
  static const bool useLocalInDebug =
      true; // (false pour prod et true pour local)
  // ==============================================================================
  // ⚙️ CONFIGURATION DES URLS
  // ==============================================================================

  static const String _prodUrl = 'https://pub-cash.com/api';
  static const String _prodSocketUrl = 'https://pub-cash.com';

  static const String _localUrl = 'http://192.168.1.11:5000/api';
  static const String _localSocketUrl = 'http://192.168.1.11:5000';

  // Logique intelligente
  static String get baseUrl {
    // Si on est en Debug ET qu'on a activé l'interrupteur local
    if (kDebugMode && useLocalInDebug) {
      return _localUrl;
    } else {
      // Sinon (Release OU interrupteur désactivé), on prend la Prod
      return _prodUrl;
    }
  }

  static String get socketUrl {
    if (kDebugMode && useLocalInDebug) {
      return _localSocketUrl;
    } else {
      return _prodSocketUrl;
    }
  }

  // ==============================================================================
  // 🛣️ ENDPOINTS
  // ==============================================================================

  static String get apiUrl => baseUrl;

  // --- Le reste ne change pas ---
  static const String login = '/auth/utilisateur/login';
  static const String register = '/auth/utilisateur/register';
  static const String googleAuth = '/auth/google';
  static const String appleAuth = '/auth/apple';
  static const String socialRegister = '/auth/social/register';
  static const String refreshToken = '/auth/refresh-token';

  static const String userProfile = '/user/profile';
  static const String updateProfile = '/user/profile';
  static const String completeProfile = '/auth/utilisateur/complete-profile';
  static const String uploadProfileImage = '/user/upload-profile-image';

  static const String villes = '/villes';
  static const String communes = '/communes';

  static const String promotions = '/promotions';
  static const String userEarnings = '/promotions/utilisateur/gains';
  static const String userVideos = '/promotions/utilisateur/historique-videos';

  static const String gamePoints = '/games/points';
  static const String gameWheel = '/games/wheel';
  static const String gameList = '/games/list';
  static const String gamePuzzleStart = '/games/puzzle/start';
  static const String gamePuzzleSubmit = '/games/puzzle/submit';

  static const String notifications = '/notifications';
  static const String notificationsUnreadCount =
      '/notifications/non-lues/count';
  static const String notificationsMarkRead = '/notifications/:id/lire';
  static const String notificationsMarkAllRead = '/notifications/lire-toutes';
  static const String notificationsToken = '/notifications/token';

  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';
}
