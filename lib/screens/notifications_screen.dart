import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/colors.dart';

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

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
  }

  Future<void> _chargerNotifications({bool reload = false}) async {
    if (reload) {
      setState(() {
        _currentPage = 1;
        _notifications = [];
        _hasMore = true;
      });
    }

    setState(() => _isLoading = true);

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

  String _formaterDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return "Il y a ${diff.inDays}j";
    if (diff.inHours > 0) return "Il y a ${diff.inHours}h";
    if (diff.inMinutes > 0) return "Il y a ${diff.inMinutes} min";
    return "À l'instant";
  }

  Future<void> _marquerCommeLue(AppNotification notif) async {
    if (!notif.lu) {
      await _notificationService.marquerCommeLue(notif.id);
      await _chargerNotifications(reload: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notifications.any((n) => !n.lu))
            IconButton(
              icon: const Icon(Icons.done_all, color: AppColors.primary),
              tooltip: 'Tout marquer comme lu',
              onPressed: () async {
                await _notificationService.marquerToutesCommeLues();
                await _chargerNotifications(reload: true);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _chargerNotifications(reload: true),
        color: AppColors.primary,
        child: _isLoading && _notifications.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Aucune notification",
                      style: TextStyle(color: Colors.grey[500], fontSize: 18),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _notifications.length) {
                    // Bouton charger plus
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: AppColors.primary,
                              )
                            : TextButton(
                                onPressed: () {
                                  _currentPage++;
                                  _chargerNotifications();
                                },
                                child: const Text('Charger plus'),
                              ),
                      ),
                    );
                  }

                  final notif = _notifications[index];
                  return _buildNotificationItem(notif);
                },
              ),
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notif) {
    return GestureDetector(
      onTap: () => _marquerCommeLue(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.lu ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.lu
                ? Colors.grey.shade200
                : AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône avec badge "non lu"
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: notif.couleur.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(notif.icone, color: notif.couleur, size: 24),
                ),
                if (!notif.lu)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Contenu
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.titre,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: notif.lu ? FontWeight.w600 : FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.contenu,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formaterDate(notif.dateCreation),
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // Montant (si applicable)
            if (notif.montantFormate != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: notif.couleur.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  notif.montantFormate!,
                  style: TextStyle(
                    color: notif.couleur,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
