import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/promotion.dart';
import 'api_service.dart';
import 'package:dio/dio.dart'; // Assure-toi d'avoir dio
import '../utils/api_constants.dart'; // N'oublie pas d'importer tes constantes
import '../utils/device_utils.dart';

class PromotionService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<List<Promotion>> getPromotions({String filter = 'toutes'}) async {
    try {
      // Utilise la constante pour être sûr de l'URL
      final response = await _apiService.get(
        ApiConstants.promotions,
        queryParameters: {'filter': filter},
      );

      final List<dynamic> data = response.data;

      // CACHE: Sauvegarde des données
      await _secureStorage.write(
        key: 'cached_promotions_$filter',
        value: jsonEncode(data),
      );

      return data.map((json) => Promotion.fromJson(json)).toList();
    } catch (e) {
      print('Erreur fetching promotions: $e');

      // CACHE: Tentative de récupération en cas d'erreur
      final cachedData = await _secureStorage.read(
        key: 'cached_promotions_$filter',
      );
      if (cachedData != null) {
        final List<dynamic> data = jsonDecode(cachedData);
        print("⚠️ Chargement promotions depuis le cache ($filter)");
        return data.map((json) => Promotion.fromJson(json)).toList();
      }

      rethrow;
    }
  }

  // CORRECTION ICI
  Future<Map<String, dynamic>> getEarnings() async {
    try {
      // Utilise la constante définie dans ApiConstants (/promotions/utilisateur/gains)
      final response = await _apiService.get(ApiConstants.userEarnings);

      // CACHE: Sauvegarde
      await _secureStorage.write(
        key: 'cached_user_earnings',
        value: jsonEncode(response.data),
      );

      return response.data;
    } catch (e) {
      print('Erreur fetching earnings: $e');

      // CACHE: Récupération
      final cachedData = await _secureStorage.read(key: 'cached_user_earnings');
      if (cachedData != null) {
        print("⚠️ Chargement earnings depuis le cache");
        return jsonDecode(cachedData);
      }

      return {'total': 0, 'per_pack': []};
    }
  }

  Future<void> likePromotion(int promoId) async {
    await _apiService.post('${ApiConstants.promotions}/$promoId/like');
  }

  Future<void> sharePromotion(int promoId) async {
    await _apiService.post('${ApiConstants.promotions}/$promoId/partage');
  }

  // === NOUVEAU : SOUMETTRE QUIZ ===
  Future<void> submitQuiz(int gameId, String reponse) async {
    try {
      // 1. On récupère l'ID de l'appareil pour la sécurité
      String? deviceId = await DeviceUtils.getDeviceId();

      // 2. On l'envoie au serveur
      await _apiService.post(
        '/games/quiz/submit',
        data: {
          'gameId': gameId,
          'reponse': reponse,
          'device_id': deviceId, // Ajout crucial
        },
      );

      // Si pas d'erreur, c'est que c'est bon
    } catch (e) {
      print("Erreur submit quiz: $e");

      // Gestion spécifique de la fraude si le serveur renvoie 403 sur le quiz
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          throw "DEVICE_FRAUD";
        }
      }
      rethrow; // On relance l'erreur pour que l'écran puisse l'attraper
    }
  }

  // === NOUVEAU : HISTORIQUE DES RETRAITS ===
  Future<List<dynamic>> getWithdrawHistory() async {
    try {
      // Endpoint basé sur PromotionController.js: getWithdrawalHistoryForUser
      final response = await _apiService.get(
        '/promotions/utilisateur/historique-retraits',
      );
      return response.data; // Retourne la liste des transactions
    } catch (e) {
      print("Erreur historique retrait: $e");
      return [];
    }
  }

  Future<List<dynamic>> getInteractionHistory() async {
    try {
      final response = await _apiService.get(
        '/promotions/utilisateur/historique-videos',
      );
      return response.data;
    } catch (e) {
      print("Erreur historique interactions: $e");
      return [];
    }
  }

  // === NOUVEAU : DEMANDE DE RETRAIT ===
  Future<void> requestWithdraw({
    required int amount,
    required String operator,
    required String phoneNumber,
  }) async {
    try {
      // Endpoint basé sur PromotionController.js: withdrawEarnings
      await _apiService.post(
        '/promotions/utilisateur/retrait',
        data: {
          'amount': amount,
          'operator': operator,
          'phoneNumber': phoneNumber,
        },
      );
    } catch (e) {
      // On relance l'erreur pour l'afficher dans l'UI (ex: solde insuffisant)
      rethrow;
    }
  }

  Future<int> markPromotionAsViewed(int promoId) async {
    try {
      String? deviceId = await DeviceUtils.getDeviceId();

      // On attend la réponse du serveur
      final response = await _apiService.post(
        '${ApiConstants.promotions}/$promoId/view',
        data: {'device_id': deviceId},
      );

      print("Vue validée avec succès.");

      // On récupère le montant envoyé par le backend (étape 1)
      // Si c'est null, on met 0 par sécurité
      return response.data['montant'] ?? 0;
    } catch (e) {
      print("Erreur validation vue: $e");

      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          throw "DEVICE_FRAUD";
        }
      }
      rethrow;
    }
  }

  // === NOUVEAU : ANNULER PROMOTION (Masquer) ===
  Future<void> cancelPromotion(int promoId) async {
    try {
      await _apiService.post('${ApiConstants.promotions}/$promoId/cancel');
    } catch (e) {
      print("Erreur lors de l'annulation de la promotion: $e");
      // On ne rethrow pas forcément ici pour ne pas bloquer la fermeture de l'écran
    }
  }

  // === NOUVEAU : AJOUTER UN COMMENTAIRE ===
  Future<void> addComment(int promotionId, String comment) async {
    try {
      await _apiService.post(
        '${ApiConstants.promotions}/$promotionId/comment',
        data: {'commentaire': comment},
      );
    } catch (e) {
      print("Erreur lors de l'ajout du commentaire: $e");
      rethrow;
    }
  }

  // === NOUVEAU : VÉRIFIER SI L'UTILISATEUR A DÉJÀ COMMENTÉ ===
  Future<bool> hasComment(int promotionId) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.promotions}/$promotionId/hasComment',
      );

      // --- DEBUG LOGS (Regarde ta console Flutter quand tu ouvres la page) ---
      print("🔍 CHECK COMMENTAIRE (ID: $promotionId) : ${response.data}");

      // On gère le cas où le backend renvoie true, "true", 1, ou "1"
      final val = response.data['hasComment'];
      if (val == true || val.toString().toLowerCase() == 'true' || val == 1) {
        return true;
      }

      return false;
    } catch (e) {
      print("❌ Erreur hasComment service: $e");
      return false;
    }
  }

  // === NOUVEAU : CONVERTIR POINTS ===
  Future<void> convertPoints({required int points, required int amount}) async {
    try {
      await _apiService.post(
        '/promotions/utilisateur/convertir-points',
        data: {'points': points, 'amount': amount},
      );
    } catch (e) {
      rethrow;
    }
  }
}
