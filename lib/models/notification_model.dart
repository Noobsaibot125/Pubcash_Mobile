import 'package:flutter/material.dart';
import 'dart:convert'; // Nécessaire pour jsonDecode si donnees est une string

class AppNotification {
  final int id;
  final String type;
  final String titre;
  final String contenu;
  final Map<String, dynamic>? donnees;
  final bool lu;
  final DateTime dateCreation;

  AppNotification({
    required this.id,
    required this.type,
    required this.titre,
    required this.contenu,
    this.donnees,
    required this.lu,
    required this.dateCreation,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // 1. GESTION ROBUSTE DE LA DATE
    // MySQL renvoie souvent "YYYY-MM-DD HH:MM:SS" qui fait planter DateTime.parse
    DateTime parsedDate = DateTime.now();
    if (json['date_creation'] != null) {
      String dateStr = json['date_creation'].toString();
      // Si la date contient un espace au lieu du T, on parse manuellement ou on remplace
      // DateTime.tryParse est plus sûr, il ne fera pas crasher l'app
      parsedDate = DateTime.tryParse(dateStr) ?? 
                   DateTime.tryParse(dateStr.replaceAll(' ', 'T')) ?? 
                   DateTime.now();
    }

    // 2. GESTION ROBUSTE DU BOOLEEN
    // MySQL renvoie 0 ou 1, pas true/false
    bool isRead = false;
    if (json['lu'] == 1 || json['lu'] == true || json['lu'] == '1') {
      isRead = true;
    }

    // 3. GESTION ROBUSTE DES DONNEES (JSON)
    Map<String, dynamic>? parsedData;
    if (json['donnees'] != null) {
      if (json['donnees'] is Map) {
        parsedData = Map<String, dynamic>.from(json['donnees']);
      } else if (json['donnees'] is String && json['donnees'].isNotEmpty) {
        try {
          parsedData = jsonDecode(json['donnees']);
        } catch (e) {
          print("Erreur parsing donnees notification: $e");
          parsedData = {};
        }
      }
    }

    return AppNotification(
      id: json['id'] ?? 0, // Sécurité si null
      type: json['type'] ?? 'info',
      titre: json['titre'] ?? 'Notification',
      contenu: json['contenu'] ?? '',
      donnees: parsedData,
      lu: isRead,
      dateCreation: parsedDate,
    );
  }

  // Icône selon le type de notification
  IconData get icone {
    switch (type) {
      case 'video_regardee':
        return Icons.play_circle_fill;
      case 'nouvelle_promo': // Type utilisé dans notificationService.js
      case 'nouvelle_video':
        return Icons.video_library;
      case 'jeu_gagne':
        return Icons.emoji_events;
      case 'retrait_initie':
        return Icons.access_time;
      case 'retrait_complete':
        return Icons.check_circle;
      case 'retrait_echec':
        return Icons.error;
      default:
        return Icons.notifications;
    }
  }

  // Couleur selon le type
  Color get couleur {
    switch (type) {
      case 'video_regardee':
        return Colors.green;
      case 'nouvelle_promo':
      case 'nouvelle_video':
        return const Color(0xFFFF8C42); // Orange PubCash
      case 'jeu_gagne':
        return Colors.amber;
      case 'retrait_initie':
        return Colors.blueGrey;
      case 'retrait_complete':
        return Colors.green;
      case 'retrait_echec':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Montant (pour affichage)
  String? get montantFormate {
    if (donnees == null) return null;

    // Gestion flexible (parfois c'est 'montant', parfois 'points')
    final montant = donnees!['montant'];
    final points = donnees!['points'];

    if (type.contains('retrait') && montant != null) {
      return '$montant Fcfa';
    } else if (type == 'jeu_gagne' && points != null) {
      return '$points pts';
    } else if (type == 'video_regardee' && montant != null) {
      return '$montant FCFA';
    }
    
    return null;
  }
}