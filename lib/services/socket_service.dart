import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/api_constants.dart';

/// Service Socket.IO pour les mises à jour en temps réel
class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  
  // Stream controller pour diffuser les nouvelles vidéos
  final _newVideoController = StreamController<Map<String, dynamic>>.broadcast();
  
  /// Stream publique pour écouter les nouvelles vidéos
  Stream<Map<String, dynamic>> get newVideoStream => _newVideoController.stream;

  /// Vérifie si le socket est connecté
  bool get isConnected => _socket?.connected ?? false;

  /// Initialise et connecte au serveur Socket.IO
  void connect() {
    if (_socket != null && _socket!.connected) {
      return;
    }

    try {
      // 1. NETTOYAGE DE L'URL (Crucial pour éviter le port :0)
      String cleanUrl = ApiConstants.socketUrl;
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }
      
      print('🔄 Connexion Socket.IO vers: $cleanUrl');

      // 2. CONFIGURATION ROBUSTE
      _socket = IO.io(
        cleanUrl,
        IO.OptionBuilder()
            .setTransports(['websocket']) // Force WebSocket
            .setPath('/socket.io')        // Force le chemin standard
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(2000)   // Délai un peu plus long
            .build(),
      );

      // --- GESTION DES ÉVÉNEMENTS ---

      _socket!.onConnect((_) {
        print('✅ Connecté à Socket.IO avec succès');
      });

      _socket!.onConnectError((error) {
        // Affiche l'erreur mais ne spamme pas trop si c'est juste une tentative
        print('❌ Erreur connexion Socket.IO: $error');
      });

      _socket!.onError((error) {
         print('❌ Erreur interne Socket.IO: $error');
      });

      _socket!.onDisconnect((_) {
        print('⚠️ Déconnecté de Socket.IO');
      });

      // Écoute de l'événement personnalisé 'new-video'
      _socket!.on('new-video', (data) {
        print('🎬 Nouvelle vidéo reçue: $data');
        if (data is Map<String, dynamic>) {
          _newVideoController.add(data);
        }
      });

      _socket!.connect();
      
    } catch (e) {
      print("❌ Exception initialisation Socket: $e");
    }
  }

  /// Déconnecte du serveur Socket.IO
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      print('🔌 Socket.IO déconnecté');
    }
  }

  void dispose() {
    disconnect();
    _newVideoController.close();
  }
}