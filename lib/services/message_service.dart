import 'dart:io'; // Nécessaire pour File si besoin, mais Dio gère le path
import 'package:dio/dio.dart';
import 'api_service.dart';

class MessageService {
  final ApiService _apiService = ApiService();

  // Récupérer la liste des conversations
  Future<List<dynamic>> getConversations() async {
    try {
      final response = await _apiService.get('/messages/conversations');
      return response.data;
    } catch (e) {
      print("Erreur getConversations: $e");
      return [];
    }
  }

  // Récupérer les messages d'une conversation
  Future<List<dynamic>> getMessages(int contactId, String contactType) async {
    try {
      final response = await _apiService.get(
        '/messages/$contactType/$contactId',
      );
      return response.data;
    } catch (e) {
      print("Erreur getMessages: $e");
      return [];
    }
  }

  // --- CORRECTION ICI ---
  // Envoyer un message (texte + image via son chemin)
  Future<void> sendMessage({
    required int receiverId,
    required String receiverType,
    String? content,
    String? imagePath, // On accepte le chemin (String) au lieu de l'objet File
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'destinataireId': receiverId,
        'destinataireType': receiverType,
        'contenu': content ?? '',
      });

      // Si un chemin d'image est fourni
      if (imagePath != null && imagePath.isNotEmpty) {
        // Dio peut créer un MultipartFile directement depuis le chemin
        formData.files.add(
          MapEntry(
            'media', 
            await MultipartFile.fromFile(imagePath),
          ),
        );
      }

      await _apiService.post('/messages/send', data: formData);
    } catch (e) {
      print("Erreur sendMessage: $e");
      rethrow;
    }
  }

  // Marquer une conversation comme lue
  Future<void> markAsRead(int contactId, String contactType) async {
    try {
      await _apiService.put('/messages/$contactType/$contactId/read');
    } catch (e) {
      print("Erreur markAsRead: $e");
    }
  }

  // Récupérer le nombre de messages non lus
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get('/messages/unread-count');
      // Gestion robuste si la réponse est null ou mal formatée
      if (response.data is Map && response.data['unreadCount'] != null) {
        return response.data['unreadCount'];
      }
      return 0;
    } catch (e) {
      print("Erreur getUnreadCount: $e");
      return 0;
    }
  }
}