import 'package:flutter/material.dart';

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
    return AppNotification(
      id: json['id'],
      type: json['type'],
      titre: json['titre'],
      contenu: json['contenu'],
      donnees: json['donnees'] != null
          ? (json['donnees'] is String
                ? {} // Si c'est une string vide ou null JSON
                : Map<String, dynamic>.from(json['donnees']))
          : null,
      lu: json['lu'] ?? false,
      dateCreation: DateTime.parse(json['date_creation']),
    );
  }

  // Icône selon le type de notification
  IconData get icone {
    switch (type) {
      case 'video_regardee':
        return Icons.play_circle;
      case 'nouvelle_video':
        return Icons.video_library;
      case 'jeu_gagne':
        return Icons.emoji_events;
      case 'retrait_initie':
        return Icons.access_time;
      case 'retrait_complete':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  // Couleur selon le type
  Color get couleur {
    switch (type) {
      case 'video_regardee':
        return Colors.green;
      case 'nouvelle_video':
        return Colors.blue;
      case 'jeu_gagne':
        return Colors.orange;
      case 'retrait_initie':
        return Colors.grey;
      case 'retrait_complete':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Image de profil (optionnel - pour les notifications de nouveaux videos)
  String? get avatarUrl {
    if (donnees != null && donnees!['promoteur_photo'] != null) {
      return donnees!['promoteur_photo'];
    }
    return null;
  }

  // Montant (pour affichage)
  String? get montantFormate {
    if (donnees == null) return null;

    final montant = donnees!['montant'];
    if (montant == null) return null;

    if (type.contains('retrait')) {
      return '$montant Fcfa';
    } else if (type == 'jeu_gagne') {
      final points = donnees!['points'] ?? montant;
      return '$points pts';
    } else {
      return '$montant FCFA';
    }
  }
}
