import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/notification_model.dart';
import 'api_service.dart';
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
  final StreamController<int> _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;

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
        provisional: false, // Important pour Android 13+
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ Permission notifications accordée');

        // --- 👇 C'EST ICI QU'IL MANQUAIT LE CODE IMPORTANT 👇 ---
        // Configuration pour iOS : Afficher la notif même app ouverte
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true, 
          badge: true,
          sound: true,
        );
        // ---------------------------------------------------------

        // 3. Configurer les notifications locales
        await _configurerNotificationsLocales();

        // 4. Récupérer le token (sans l'envoyer tout de suite si pas login, 
        // mais le listener s'en charge si ça change)
        final token = await _fcm.getToken();
        print("🔑 Token actuel : $token");

        // 5. Écouter les changements de token
        _fcm.onTokenRefresh.listen(_envoyerTokenAuBackend);

        // 6. Gérer les notifications en premier plan
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print("📡 Message reçu en premier plan : ${message.notification?.title}");
          _afficherNotificationLocale(message);
        });

        // 7. Gérer les clics sur notifications
        FirebaseMessaging.onMessageOpenedApp.listen(_gererClicNotification);

        // 8. Gérer les notifications reçues quand l'app était fermée
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null) {
            _gererClicNotification(message);
          }
        });

        // 9. Initialiser le compteur de badge
        await refreshUnreadCount();

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
    
    // Configuration iOS pour permettre l'affichage app ouverte
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
      onDidReceiveNotificationResponse: (details) {
        print('Notification locale cliquée: ${details.payload}');
      },
    );

    const androidChannel = AndroidNotificationChannel(
      'pubcash_notifications',
      'Notifications PubCash',
      description: 'Notifications pour les gains, retraits et nouvelles vidéos',
      importance: Importance.max, // --- 👇 IMPORTANT : Mettre MAX ici ---
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Envoyer le token FCM au backend
  Future<void> _envoyerTokenAuBackend(String token) async {
    try {
      print("🚀 Envoi du token au backend...");
      await _apiService.post('/notifications/token', data: {'token': token});
      print("✅ Token FCM sauvegardé au backend");
    } catch (e) {
      // On ignore l'erreur silencieusement si l'user n'est pas encore connecté
      // Car forceRefreshToken() le fera plus tard
      print("ℹ️ Token non envoyé (Probablement pas connecté): $e");
    }
  }

  /// Force l'envoi du token actuel (Appelé après Login)
  Future<void> forceRefreshToken() async {
    try {
      if (!_initialized) await Firebase.initializeApp();
      
      final token = await _fcm.getToken();
      if (token != null) {
        print("🔄 Envoi forcé du token FCM...");
        // Ici on veut voir l'erreur si ça échoue
        final response = await _apiService.post('/notifications/token', data: {'token': token});
        if (response.statusCode == 200 || response.statusCode == 201) {
           print("✅ Token mis à jour avec succès !");
        }
      }
    } catch (e) {
      print("❌ Impossible de rafraîchir le token FCM : $e");
    }
  }

  /// Afficher une notification locale quand l'app est au premier plan
  Future<void> _afficherNotificationLocale(RemoteMessage message) async {
    // 1. Mettre à jour le badge
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
              'pubcash_notifications',
              'Notifications PubCash',
              channelDescription: 'Notifications importantes',
              // --- 👇 IMPORTANT : Importance MAX et Priorité HIGH pour le POPUP ---
              importance: Importance.max, 
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true, // Force le popup sur iOS
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

  /// Supprimer une notification
  Future<void> supprimerNotification(int notificationId) async {
    try {
      await _apiService.delete('/notifications/$notificationId');
      await refreshUnreadCount(); // On met à jour au cas où
    } catch (e) {
      print('❌ Erreur suppression notification: $e');
    }
  }
}