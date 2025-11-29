import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  // On garde votre ApiService, c'est très bien
  final ApiService _apiService = ApiService();

  bool _initialized = false;

  /// Initialiser le service de notifications
  Future<void> initialiser() async {
    if (_initialized) return;

    try {
      // 1. Initialiser Firebase
      await Firebase.initializeApp();

      // 2. Demander la permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permission notifications accordée');

        // 3. Configurer les notifications locales
        await _configurerNotificationsLocales();

        // 4. Récupérer et envoyer le token FCM au backend
        final token = await _fcm.getToken();
        if (token != null) {
          await _envoyerTokenAuBackend(token);
        }

        // 5. Écouter les changements de token
        _fcm.onTokenRefresh.listen(_envoyerTokenAuBackend);

        // 6. Gérer les notifications en premier plan
        FirebaseMessaging.onMessage.listen(_afficherNotificationLocale);

        // 7. Gérer les clics sur notifications
        FirebaseMessaging.onMessageOpenedApp.listen(_gererClicNotification);

        // 8. Gérer les notifications reçues quand l'app était fermée
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) {
            _gererClicNotification(message);
          }
        });

        _initialized = true;
      } else {
        print('❌ Permission notifications refusée');
      }
    } catch (e) {
      print('❌ Erreur initialisation notifications: $e');
    }
  }

  /// Configurer les notifications locales (affichage en premier plan)
  Future<void> _configurerNotificationsLocales() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print('Notification cliquée: ${details.payload}');
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'pubcash_notifications',
      'Notifications PubCash',
      description: 'Notifications pour les gains, retraits et nouvelles vidéos',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Envoyer le token FCM au backend
  Future<void> _envoyerTokenAuBackend(String token) async {
    try {
      await _apiService.post('/notifications/token', data: {'token': token});
      print('✅ Token FCM envoyé au backend');
    } catch (e) {
      print('❌ Erreur envoi token: $e');
    }
  }

  /// Afficher une notification locale quand l'app est au premier plan
  Future<void> _afficherNotificationLocale(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pubcash_notifications',
            'Notifications PubCash',
            channelDescription:
                'Notifications pour les gains, retraits et nouvelles vidéos',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data.toString(),
      );
    }
  }

  /// Gérer le clic sur une notification
  void _gererClicNotification(RemoteMessage message) {
    print('Notification cliquée: ${message.data}');
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
      print('✅ Notification $notificationId marquée comme lue');
    } catch (e) {
      print('❌ Erreur marquage notification: $e');
    }
  }

  /// Marquer toutes les notifications comme lues
  Future<void> marquerToutesCommeLues() async {
    try {
      await _apiService.patch('/notifications/lire-toutes');
      print('✅ Toutes les notifications marquées comme lues');
    } catch (e) {
      print('❌ Erreur marquage toutes notifications: $e');
    }
  }

  // --- CORRECTION ICI : Changement de nom de getNombreNonLues vers getUnreadCount ---
  /// Obtenir le nombre de notifications non lues
  Future<int> getUnreadCount() async {
    try {
      // Note: Assure-toi que la route backend correspond bien
      final response = await _apiService.get('/notifications/non-lues/count');
      
      // Adaptation selon le format de réponse de ton ApiService (probablement Dio)
      if (response.data is Map && response.data['success'] == true) {
        return response.data['count'] ?? 0;
      } else if (response.data is Map && response.data['count'] != null) {
         return response.data['count'];
      }
      
      return 0;
    } catch (e) {
      print('❌ Erreur comptage notifications: $e');
      return 0;
    }
  }

  /// Supprimer une notification
  Future<void> supprimerNotification(int notificationId) async {
    try {
      await _apiService.delete('/notifications/$notificationId');
      print('✅ Notification $notificationId supprimée');
    } catch (e) {
      print('❌ Erreur suppression notification: $e');
    }
  }
}