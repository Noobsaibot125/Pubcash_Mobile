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
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              );
            }
            
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                height: 150,
                child: const Center(child: Text("Vous ne suivez aucun promoteur pour le moment.")),
              );
            }

            final following = snapshot.data!;

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Nouveau message", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          child: photoUrl == null ? const Icon(Icons.person) : null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messagerie", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewMessageDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      Text("Aucune conversation", style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _showNewMessageDialog, 
                        child: const Text("Démarrer une discussion", style: TextStyle(color: AppColors.primary))
                      )
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final conv = _conversations[i];
                      final unreadCount = conv['unreadCount'] ?? 0;
                      final contactName = conv['contactName'] ?? 'Inconnu';
                      final lastMessage = conv['lastMessage'] ?? '';
                      final lastMessageType = conv['lastMessageType'];
                      
                      // Utilisation de la fonction pour l'image
                      final contactPhotoUrl = _getProfileUrl(conv['contactPhoto']);

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
                          style: TextStyle(fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal),
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
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            color: unreadCount > 0 ? Colors.black87 : Colors.grey,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDate(conv['lastMessageDate']),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
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
                              ),
                            ),
                          ).then((_) => _loadConversations());
                        },
                      );
                    },
                  ),
                ),
    );
  }
}