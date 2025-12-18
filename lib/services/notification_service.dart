import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import 'api_service.dart';
import 'package:pubcash_mobile/main.dart'; // Adapte selon le nom de ton projet
import '../../services/notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final ApiService _apiService = ApiService();

  bool _initialized = false;

  // Le flux pour la cloche (Badge)
  final StreamController<int> _unreadCountController =
      StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      print("❌ Erreur getToken FCM : $e");
      return null;
    }
  }

  /// Initialiser le service de notifications
  Future<void> initialiser() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();

      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permission notifications accordée');

        // iOS Configuration
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // Configuration Locale
        await _configurerNotificationsLocales();

        // Token
        final token = await _fcm.getToken();
        print("🔑 Token actuel : $token");

        _fcm.onTokenRefresh.listen(_envoyerTokenAuBackend);

        // Écoute PREMIER PLAN
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print(
            "📡 Message reçu en premier plan : ${message.notification?.title}",
          );
          _afficherNotificationLocale(message);
        });

        // Clics
        FirebaseMessaging.onMessageOpenedApp.listen(_gererClicNotification);
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) {
            _gererClicNotification(message);
          }
        });

        await refreshUnreadCount();
        _initialized = true;
      }
    } catch (e) {
      print('❌ Erreur initialisation notifications: $e');
    }
  }

  /// Configurer les notifications locales (affichage en premier plan)
  Future<void> _configurerNotificationsLocales() async {
    // ⚠️ CORRECTION ICI : On utilise launcher_icon car c'est le fichier qui existe
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      // 👇👇👇 C'EST ICI LA MODIFICATION IMPORTANTE (Clic App Ouverte) 👇👇👇
      onDidReceiveNotificationResponse: (details) {
        print('🖱️ Clic sur notification locale (App ouverte)');
        // On utilise la clé globale pour aller à l'accueil
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      },
      // 👆👆👆 FIN MODIFICATION 👆👆👆
    );

    const androidChannel = AndroidNotificationChannel(
      'pubcash_notifications_v3', // <--- PASSAGE EN V3 POUR FORCER LA MISE A JOUR
      'Notifications PubCash',
      description: 'Notifications pour les gains, retraits et nouvelles vidéos',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  /// Envoyer le token FCM au backend
  Future<void> _envoyerTokenAuBackend(String token) async {
    try {
      await _apiService.post('/notifications/token', data: {'token': token});
    } catch (e) {
      print("ℹ️ Token non envoyé: $e");
    }
  }

  Future<void> forceRefreshToken() async {
    try {
      if (!_initialized) await Firebase.initializeApp();
      final token = await _fcm.getToken();
      if (token != null)
        await _apiService.post('/notifications/token', data: {'token': token});
    } catch (e) {
      print("❌ Refresh token error: $e");
    }
  }

  /// Afficher une notification locale quand l'app est au premier plan
  Future<void> _afficherNotificationLocale(RemoteMessage message) async {
    await refreshUnreadCount();

    final notification = message.notification;

    if (notification != null) {
      try {
        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'pubcash_notifications_v3',
              'Notifications PubCash',
              channelDescription: 'Notifications importantes',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/launcher_icon',
              playSound: true,
              enableVibration: true,
              visibility: NotificationVisibility.public,

              // 👇 AJOUT DE LA COULEUR ORANGE ICI 👇
              color: Color(0xFFFF8C42),
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );
      } catch (e) {
        print("❌ Erreur affichage notif locale : $e");
      }
    }
  }

  /// Gérer le clic sur une notification
  void _gererClicNotification(RemoteMessage message) {
    print('Notification cliquée: ${message.data}');
    // Idéalement ici, on navigue vers l'écran concerné et on rafraichit le badge
    refreshUnreadCount();
    // --- AJOUT : Gestion spécifique pour les messages ---
    if (message.data['type'] == 'nouveau_message') {
      // On redirige vers l'index 3 (l'onglet Messages dans MainNavigationScreen)
      // Note : Cela suppose que tu passes un argument ou utilises un Provider pour changer l'index.
      // Une solution simple est de renvoyer vers /home et laisser l'utilisateur voir le badge.
      // Si tu as un système de routage avancé, tu peux push vers InboxScreen directement.

      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/home', // On va à l'accueil
        (route) => false,
        arguments: {
          'tabIndex': 3,
        }, // Optionnel : Si ton HomeScreen gère les arguments pour changer d'onglet
      );
      return;
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    });
  }

  // === NOUVELLE FONCTION : Notification Locale Immédiate ===
  Future<void> showInstantNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'pubcash_notifications_v3',
      'Notifications PubCash',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/launcher_icon',
      color: Color(0xFFFF8C42), // Orange PubCash
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond, // ID unique
      title,
      body,
      details,
    );
  }

  /// Récupérer les notifications depuis l'API
  Future<List<AppNotification>> recupererNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiService.get(
        '/notifications?page=$page&limit=$limit',
      );

      if (response.data['success'] == true) {
        final List notificationsJson = response.data['notifications'] ?? [];

        // On profite de cet appel pour rafraîchir le compteur global
        // car l'API renvoie souvent le compteur avec la liste
        if (response.data['unreadCount'] != null) {
          _unreadCountController.add(response.data['unreadCount']);
        }

        return notificationsJson
            .map((json) => AppNotification.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Erreur récupération notifications: $e');
      return [];
    }
  }

  /// Marquer une notification comme lue
  Future<void> marquerCommeLue(int notificationId) async {
    try {
      await _apiService.patch('/notifications/$notificationId/lire');
      // Mise à jour du badge après lecture
      await refreshUnreadCount();
    } catch (e) {
      print('❌ Erreur marquage notification: $e');
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<void> marquerToutesCommeLues() async {
    try {
      await _apiService.patch('/notifications/lire-toutes');
      // On force le compteur à 0
      _unreadCountController.add(0);
    } catch (e) {
      print('❌ Erreur marquage toutes notifications: $e');
    }
  }

  /// Obtenir le nombre de notifications non lues
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get('/notifications/non-lues/count');

      int count = 0;
      if (response.data is Map && response.data['success'] == true) {
        count = response.data['count'] ?? 0;
      } else if (response.data is Map && response.data['count'] != null) {
        count = response.data['count'];
      }

      // On pousse le nouveau chiffre dans le Stream
      _unreadCountController.add(count);

      return count;
    } catch (e) {
      print('❌ Erreur comptage notifications: $e');
      return 0;
    }
  }

  /// Helper pour rafraîchir manuellement le compteur
  Future<void> refreshUnreadCount() async {
    await getUnreadCount();
  }

  /// Supprimer toutes les notifications
  Future<void> supprimerToutesNotifications() async {
    try {
      // Adapte l'endpoint selon ton backend (ex: /notifications/tout ou delete sur /notifications)
      await _apiService.delete('/notifications/toutes');

      // On met à jour le compteur à 0
      _unreadCountController.add(0);
    } catch (e) {
      print('❌ Erreur suppression totale: $e');
      throw e; // On renvoie l'erreur pour gérer l'UI
    }
  }

  // --- RAPPEL : TU AS DÉJÀ CETTE MÉTHODE, GARDE-LA ---
  /// Supprimer une notification
  Future<void> supprimerNotification(int notificationId) async {
    try {
      await _apiService.delete('/notifications/$notificationId');
      await refreshUnreadCount();
    } catch (e) {
      print('❌ Erreur suppression notification: $e');
    }
  }

  /// Afficher une notification locale manuelle (Public)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pubcash_notifications_v3',
      'Notifications PubCash',
      channelDescription: 'Notifications importantes',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond, // ID unique
      title,
      body,
      details,
      payload: payload,
    );
  }
}
