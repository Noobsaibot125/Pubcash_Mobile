import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/colors.dart';
import '../utils/api_constants.dart'; // 👈 IMPORT IMPORTANT
import 'simple_video_player.dart';
import 'gains/transaction_details_screen.dart';
import 'messaging/chat_screen.dart';
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;

  // ✅ CORRECTION : On utilise la constante de production définie dans ApiConstants
  // Cela vaut "https://pub-cash.com"
  final String _baseUrl = ApiConstants.socketUrl;

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
  }

  Future<void> _chargerNotifications({bool reload = false}) async {
    if (reload) {
      if (mounted)
        setState(() {
          _currentPage = 1;
          _notifications = [];
          _hasMore = true;
        });
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final nouvelles = await _notificationService.recupererNotifications(
        page: _currentPage,
        limit: 20,
      );

      if (mounted) {
        setState(() {
          if (reload) {
            _notifications = nouvelles;
          } else {
            _notifications.addAll(nouvelles);
          }
          _hasMore = nouvelles.length == 20;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur chargement notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }
// --- NOUVEAU : Fonction pour supprimer tout avec confirmation ---
  Future<void> _confirmDeleteAll() async {
    if (_notifications.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tout supprimer ?"),
        content: const Text("Voulez-vous vraiment effacer toutes vos notifications ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _notificationService.supprimerToutesNotifications();
        if (mounted) {
          setState(() {
            _notifications.clear();
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Notifications supprimées")),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erreur lors de la suppression")),
          );
        }
      }
    }
  }

  // --- NOUVEAU : Fonction pour supprimer une seule (Swipe) ---
  Future<void> _deleteSingleNotification(int id, int index) async {
    // 1. Suppression optimiste UI (on retire tout de suite pour la fluidité)
    final removedItem = _notifications[index];
    setState(() {
      _notifications.removeAt(index);
    });

    try {
      // 2. Appel API
      await _notificationService.supprimerNotification(id);
    } catch (e) {
      // 3. Si erreur, on remet l'item (optionnel, mais propre)
      if (mounted) {
        setState(() {
          _notifications.insert(index, removedItem);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de supprimer la notification")),
        );
      }
    }
  }


  String _formaterDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return "Il y a ${diff.inDays}j";
    if (diff.inHours > 0) return "Il y a ${diff.inHours}h";
    if (diff.inMinutes > 0) return "Il y a ${diff.inMinutes}min";
    return "À l'instant";
  }

  // --- GESTION DU CLIC ---
  // --- GESTION DU CLIC ---
  Future<void> _handleNotificationClick(AppNotification notif) async {
    if (!notif.lu) {
      _notificationService.marquerCommeLue(notif.id);
      setState(() {});
    }

    print("Clic Notification Type: ${notif.type}");
// --- AJOUT : GESTION DU CLIC SUR UN MESSAGE ---
    if (notif.type == 'nouveau_message') {
      if (notif.donnees != null && notif.donnees!['sender_id'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              contactId: int.parse(notif.donnees!['sender_id'].toString()),
              contactType: notif.donnees!['sender_type'] ?? 'client',
              // On utilise le titre de la notif comme nom par défaut ou on cherche dans les données
              contactName: notif.donnees?['sender_name'] ?? notif.titre.replaceAll('Nouveau message', '').trim(), 
              contactPhoto: notif.donnees?['sender_photo'],
            ),
          ),
        );
      }
      return;
    }
    // 1. CAS RETRAIT (Nouveau) -> TransactionDetailsScreen
    if (notif.type.contains('retrait')) {
      // On prépare les données pour l'écran de détails
      // On essaie de récupérer le statut depuis les données, sinon on le déduit du type
      String statut = notif.donnees?['statut'] ?? 'en_cours';
      if (notif.type == 'retrait_complete') statut = 'succes';
      if (notif.type == 'retrait_echec') statut = 'echec';

      final Map<String, dynamic> transactionData = {
        'montant': notif.donnees?['montant'] ?? '0',
        'statut': statut,
        'date': notif.dateCreation
            .toIso8601String(), // On utilise la date de la notif
        'operator':
            notif.donnees?['operator'] ??
            notif.donnees?['operateur'] ??
            'Mobile',
        'transaction_id': notif.donnees?['transaction_id'] ?? 'N/A',
        'numero_telephone':
            notif.donnees?['numero_telephone'] ?? 'Non spécifié',
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TransactionDetailsScreen(transaction: transactionData),
        ),
      );
      return;
    }

    // 2. CAS NOUVELLE VIDÉO -> Accueil
    if (notif.type == 'nouvelle_video' || notif.type == 'nouvelle_promo') {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      return;
    }

    // 3. CAS VIDÉO REGARDÉE -> Player
    if (notif.type == 'video_regardee' || notif.type == 'felicitations') {
      String? videoUrl = notif.donnees?['url_video'];
      String titre = notif.donnees?['titre'] ?? 'Gain validé';

      if (videoUrl != null && videoUrl.isNotEmpty) {
        if (!videoUrl.startsWith('http')) {
          if (videoUrl.startsWith('/')) videoUrl = videoUrl.substring(1);
          videoUrl = "$_baseUrl/$videoUrl";
        }

        print("Lecture vidéo prod : $videoUrl");

        // Extraction des infos promoteur si disponibles
        int? promoterId;
        if (notif.donnees?['client_id'] != null)
          promoterId = int.tryParse(notif.donnees!['client_id'].toString());
        if (promoterId == null && notif.donnees?['promoter_id'] != null)
          promoterId = int.tryParse(notif.donnees!['promoter_id'].toString());

        String? promoterName = notif.donnees?['promoter_name'];
        String? promoterAvatar = notif.donnees?['promoter_avatar'];
        int? promotionId;
        if (notif.donnees?['promotion_id'] != null)
          promotionId = int.tryParse(notif.donnees!['promotion_id'].toString());
        if (promotionId == null && notif.donnees?['id'] != null)
          promotionId = int.tryParse(notif.donnees!['id'].toString());

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleVideoPlayer(
              videoUrl: videoUrl!,
              title: titre,
              promoterId: promoterId,
              promoterName: promoterName,
              promoterAvatar: promoterAvatar,
              promotionId: promotionId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vidéo indisponible ou lien expiré.")),
        );
      }
    }
  }

 String _getValidImageUrl(String path, String folder) {
    if (path.isEmpty) return "";
    if (path.startsWith('http')) return path;
    
    // Si le chemin contient déjà 'uploads', on ne rajoute pas le dossier
    if (path.contains('uploads/')) {
        // On s'assure juste qu'il n'y a pas de double slash au début
        if (path.startsWith('/')) return "$_baseUrl$path";
        return "$_baseUrl/$path";
    }

    // Sinon, comportement standard
    if (path.startsWith('/')) path = path.substring(1);
    return "$_baseUrl/uploads/$folder/$path";
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Bouton 1: Tout marquer comme lu
          IconButton(
            tooltip: "Tout marquer comme lu",
            icon: const Icon(Icons.done_all, color: AppColors.primary),
            onPressed: () async {
              await _notificationService.marquerToutesCommeLues();
              _chargerNotifications(reload: true);
            },
          ),
          // Bouton 2: Tout supprimer (NOUVEAU)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              tooltip: "Tout supprimer",
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
              onPressed: _confirmDeleteAll,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _chargerNotifications(reload: true),
        color: AppColors.primary,
        child: _notifications.isEmpty && !_isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text(
                      "Aucune notification",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                itemCount: _notifications.length + (_hasMore ? 1 : 0),
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == _notifications.length) {
                    return _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          )
                        : TextButton(
                            onPressed: () {
                              _currentPage++;
                              _chargerNotifications();
                            },
                            child: const Text("Voir plus"),
                          );
                  }
                  
                  final notif = _notifications[index];

                  // --- NOUVEAU : Dismissible pour le Swipe ---
                  return Dismissible(
                    // La clé doit être unique pour chaque item
                    key: Key('notif_${notif.id}'),
                    direction: DismissDirection.endToStart, // Swipe de droite à gauche uniquement
                    
                    // L'arrière-plan rouge quand on swipe
                    background: Container(
                      padding: const EdgeInsets.only(right: 20),
                      alignment: Alignment.centerRight,
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 30),
                    ),
                    
                    // L'action déclenchée
                    onDismissed: (direction) {
                      _deleteSingleNotification(notif.id, index);
                    },
                    
                    // La carte normale
                    child: _buildNotificationCard(notif),
                  );
                },
              ),
      ),
    );
  }


  Widget _buildNotificationCard(AppNotification notif) {
    bool hasThumbnail =
        (notif.type == 'video_regardee' ||
            notif.type == 'nouvelle_video' ||
            notif.type == 'felicitations') &&
        notif.donnees != null &&
        notif.donnees!['thumbnail_url'] != null;

    return GestureDetector(
      onTap: () => _handleNotificationClick(notif),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notif.lu ? Colors.white : const Color(0xFFFFFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeadingIcon(notif),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.titre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notif.lu ? FontWeight.w600 : FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.contenu,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formaterDate(notif.dateCreation),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasThumbnail)
              _buildThumbnail(notif)
            else if (notif.montantFormate != null)
              _buildAmountBadge(notif.montantFormate!),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(AppNotification notif) {
    if (notif.type == 'nouveau_message') {
      // On récupère le chemin de la photo envoyé par le backend
      String? photoPath = notif.donnees?['sender_photo'];

      if (photoPath != null && photoPath.isNotEmpty) {
        // On construit l'URL complète en utilisant ton helper existant
        // On suppose que les photos de profil sont dans le dossier 'profile'
        String fullUrl = _getValidImageUrl(photoPath, "profile");

        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200),
            image: DecorationImage(
              image: NetworkImage(fullUrl),
              fit: BoxFit.cover,
              onError: (exception, stackTrace) {
                // Gestion d'erreur silencieuse si l'image ne charge pas
              }
            ),
          ),
        );
      } else {
        // Si pas de photo, on affiche une icône de personne colorée
        return _buildIconContainer(
          const Icon(Icons.person, color: AppColors.primary, size: 26),
          AppColors.primary.withOpacity(0.1),
        );
      }
    }
    if (notif.type.contains('retrait') && notif.donnees != null) {
      var rawOp =
          notif.donnees!['operator'] ??
          notif.donnees!['operateur'] ??
          notif.donnees!['operateur_mobile'];

      String asset = 'assets/images/logo.png';
      if (rawOp != null) {
        String op = rawOp.toString().toLowerCase().trim();
        if (op.contains('orange'))
          asset = 'assets/images/Orange.png';
        else if (op.contains('mtn'))
          asset = 'assets/images/MTN.png';
        else if (op.contains('moov'))
          asset = 'assets/images/Moov.png';
        else if (op.contains('wave'))
          asset = 'assets/images/Wave.png';
      }
      return _buildAssetIcon(asset);
    }

    if (notif.type == 'roue_fortune' || notif.type.contains('jeu')) {
      return Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFFF8E1),
        ),
        padding: const EdgeInsets.all(6),
        child: Image.asset('assets/images/Wheel.png', fit: BoxFit.contain),
      );
    }

    if (notif.type == 'video_regardee' || notif.type == 'felicitations') {
      return _buildIconContainer(
        const Icon(Icons.check_circle, color: Colors.green, size: 26),
        Colors.green.withOpacity(0.1),
      );
    }
    if (notif.type == 'nouvelle_video') {
      return _buildIconContainer(
        const Icon(Icons.play_circle_fill, color: Colors.orange, size: 26),
        Colors.orange.withOpacity(0.1),
      );
    }

    return _buildIconContainer(
      const Icon(Icons.notifications, color: Colors.grey),
      Colors.grey.withOpacity(0.1),
    );
  }

  Widget _buildAssetIcon(String path) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
        border: Border.all(color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildIconContainer(Widget child, Color bg) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: child,
    );
  }

  Widget _buildThumbnail(AppNotification notif) {
    String thumbUrl = notif.donnees!['thumbnail_url'];
    thumbUrl = _getValidImageUrl(thumbUrl, "thumbnails");

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 80,
            height: 45,
            color: Colors.black12,
            child: Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, o, s) =>
                  const Icon(Icons.broken_image, size: 20, color: Colors.grey),
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, size: 14, color: Colors.black),
        ),
      ],
    );
  }

  Widget _buildAmountBadge(String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        amount,
        style: const TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
