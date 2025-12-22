import 'package:flutter/material.dart';
import 'package:pubcash_mobile/utils/api_constants.dart';
import '../../services/message_service.dart';
import '../../services/follow_service.dart';
import '../../utils/colors.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final MessageService _messageService = MessageService();
  final FollowService _followService = FollowService();

  List<dynamic> _conversations = [];
  bool _isLoading = true;
  Map<int, bool> _followStatus = {}; // Statut de suivi pour chaque contact
  Set<int> _hiddenConversations = {}; // Conversations masquées localement

  // AJOUT : Ton URL de base (Change l'IP si nécessaire)
  // final String _baseUrl = "http://192.168.1.15:5000";
  final String _baseUrl = ApiConstants.socketUrl;
  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final convs = await _messageService.getConversations();

      // Vérifier le statut de suivi pour chaque conversation
      for (var conv in convs) {
        if (conv['contactType'] == 'client') {
          try {
            final isFollowing = await _followService.isFollowing(
              conv['contactId'],
            );
            _followStatus[conv['contactId']] = isFollowing;
          } catch (e) {
            _followStatus[conv['contactId']] = false;
          }
        }
      }

      setState(() {
        _conversations = convs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // AJOUT : Fonction pour construire l'URL correcte
  String? _getProfileUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    // Si le chemin commence par un slash (ex: /uploads/...), on concatène juste
    if (path.startsWith('/')) return "$_baseUrl$path";
    // Sinon on suppose que c'est dans uploads/profile/
    return "$_baseUrl/uploads/profile/$path";
  }

  void _showNewMessageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<dynamic>>(
          future: _followService.getFollowing(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                height: 150,
                child: const Center(
                  child: Text("Vous ne suivez aucun promoteur pour le moment."),
                ),
              );
            }

            final following = snapshot.data!;

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Nouveau message",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: following.length,
                    itemBuilder: (context, index) {
                      final promoter = following[index];
                      final photoUrl = _getProfileUrl(promoter['photo_profil']);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(promoter['nom_utilisateur'] ?? 'Inconnu'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                contactId: promoter['id'],
                                contactType: 'client',
                                contactName: promoter['nom_utilisateur'],
                                contactPhoto: promoter['photo_profil'],
                              ),
                            ),
                          ).then((_) => _loadConversations());
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (diff.inDays == 1) {
      return "Hier";
    } else {
      return "${date.day}/${date.month}";
    }
  }

  // --- GESTION DES OPTIONS DE CONVERSATION ---

  void _showConversationOptions(
    int contactId,
    String contactName,
    bool isFollowing,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Options pour '$contactName'",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(),

              // Option 1 : Masquer la conversation
              ListTile(
                leading: const Icon(Icons.visibility_off, color: Colors.grey),
                title: const Text("Masquer la conversation"),
                subtitle: const Text(
                  "La conversation disparaîtra de la liste.",
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _hideConversation(contactId);
                },
              ),

              const Divider(),

              // Option 2 : Se désabonner / Se réabonner
              if (isFollowing)
                ListTile(
                  leading: const Icon(Icons.person_remove, color: Colors.red),
                  title: const Text(
                    "Se désabonner",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUnfollowDialog(
                      contactId,
                      contactName,
                    ); // Appel confirmation
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.green),
                  title: const Text(
                    "Se réabonner",
                    style: TextStyle(color: Colors.green),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showResubscribeDialog(
                      contactId,
                      contactName,
                    ); // Appel confirmation
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _hideConversation(int contactId) {
    setState(() {
      _hiddenConversations.add(contactId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Conversation masquée."),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showUnfollowDialog(int clientId, String clientName) async {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text("Se désabonner"),
          content: Text(
            "Voulez-vous vous désabonner de '$clientName' ?\n\nVous ne recevrez plus de messages.",
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                "Annuler",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _unfollowPromoter(clientId, clientName);
              },
              child: const Text(
                "Se désabonner",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unfollowPromoter(int clientId, String clientName) async {
    try {
      await _followService.unfollowPromoter(clientId);
      if (mounted) {
        setState(() {
          _followStatus[clientId] = false;
          _hiddenConversations.add(clientId); // AUTO-HIDE
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Vous ne suivez plus '$clientName'. Conversation masquée.",
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showResubscribeDialog(int clientId, String clientName) async {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text("Se réabonner"),
          content: Text(
            "Voulez-vous suivre à nouveau '$clientName' ?",
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                "Annuler",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _resubscribePromoter(clientId, clientName);
              },
              child: const Text(
                "Se réabonner",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resubscribePromoter(int clientId, String clientName) async {
    try {
      await _followService.followPromoter(clientId);

      if (mounted) {
        setState(() {
          _followStatus[clientId] = true;
          _hiddenConversations.remove(clientId); // AUTO-UNHIDE on Resubscribe
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Vous suivez maintenant '$clientName'"),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );

        _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors du réabonnement: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showHiddenListDialog() {
    // Filtrer les conversations qui sont dans le set _hiddenConversations
    final hiddenList = _conversations.where((conv) {
      return _hiddenConversations.contains(conv['contactId']);
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        // Nécessaire pour mettre à jour la liste dans le dialog si on restaure
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Conversations Masquées"),
              content: SizedBox(
                width: double.maxFinite,
                child: hiddenList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text("Aucune conversation masquée."),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: hiddenList.length,
                        itemBuilder: (ctx, i) {
                          final conv = hiddenList[i];
                          final id = conv['contactId'];
                          final name = conv['contactName'] ?? 'Inconnu';
                          final photo = _getProfileUrl(conv['contactPhoto']);
                          final isFollowing = _followStatus[id] ?? false;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: photo != null
                                  ? NetworkImage(photo)
                                  : null,
                              child: photo == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(name),
                            subtitle: Text(
                              isFollowing
                                  ? "Masqué manuellement"
                                  : "Désabonné (Invisible)",
                              style: TextStyle(
                                fontSize: 12,
                                color: isFollowing ? Colors.grey : Colors.red,
                                fontStyle: isFollowing
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                            trailing: isFollowing
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.visibility,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () {
                                      // Action : Réafficher (Juste on retire du set)
                                      setState(() {
                                        _hiddenConversations.remove(id);
                                      });
                                      // On retire aussi de la liste locale du dialog pour l'UX
                                      setStateDialog(() {
                                        hiddenList.removeAt(i);
                                      });
                                    },
                                    tooltip: "Réafficher",
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.person_add,
                                      color: AppColors.primary,
                                    ),
                                    onPressed: () async {
                                      // Action : Se réabonner (ce qui va aussi Unhide via _resubscribePromoter)
                                      Navigator.of(
                                        context,
                                      ).pop(); // On ferme le dialog
                                      await _showResubscribeDialog(id, name);
                                    },
                                    tooltip: "Se réabonner pour réafficher",
                                  ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Fermer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Messagerie",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (_hiddenConversations.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.visibility, color: AppColors.primary),
              tooltip: "Gérer les conversations masquées",
              onPressed: _showHiddenListDialog,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMessageDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 60,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Aucune conversation",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _showNewMessageDialog,
                    child: const Text(
                      "Démarrer une discussion",
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: Builder(
                builder: (context) {
                  // Filtrer les conversations masquées
                  final visibleConversations = _conversations.where((conv) {
                    return !_hiddenConversations.contains(conv['contactId']);
                  }).toList();

                  if (visibleConversations.isEmpty &&
                      _conversations.isNotEmpty) {
                    return const Center(
                      child: Text("Toutes les conversations sont masquées."),
                    );
                  }

                  return ListView.builder(
                    itemCount: visibleConversations.length,
                    itemBuilder: (ctx, i) {
                      final conv = visibleConversations[i];
                      final unreadCount = conv['unreadCount'] ?? 0;
                      final contactName = conv['contactName'] ?? 'Inconnu';
                      final lastMessage = conv['lastMessage'] ?? '';
                      final lastMessageType = conv['lastMessageType'];
                      final contactPhotoUrl = _getProfileUrl(
                        conv['contactPhoto'],
                      );
                      final isFollowing =
                          _followStatus[conv['contactId']] ?? false;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          backgroundImage: contactPhotoUrl != null
                              ? NetworkImage(contactPhotoUrl)
                              : null,
                          child: contactPhotoUrl == null
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          contactName,
                          style: TextStyle(
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          lastMessageType == 'image'
                              ? '📷 Photo'
                              : lastMessageType == 'video'
                              ? '🎥 Vidéo'
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(conv['lastMessageDate']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                contactId: conv['contactId'],
                                contactType: conv['contactType'],
                                contactName: contactName,
                                contactPhoto: conv['contactPhoto'],
                                isFollowing: isFollowing,
                              ),
                            ),
                          ).then((_) => _loadConversations());
                        },
                        onLongPress: () {
                          if (conv['contactType'] == 'client') {
                            _showConversationOptions(
                              conv['contactId'],
                              contactName,
                              isFollowing,
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}
