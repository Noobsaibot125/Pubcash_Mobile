import 'dart:convert'; // Pour décoder le token si besoin (ou juste simuler)
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
// IMPORT IMPORTANT POUR LE SOCKET
import 'package:socket_io_client/socket_io_client.dart' as IO;
// Pour récupérer l'ID de l'utilisateur connecté (stockage local)
import 'package:shared_preferences/shared_preferences.dart'; 

import 'package:pubcash_mobile/utils/api_constants.dart';
import '../../services/message_service.dart';
import '../../utils/colors.dart';
import 'package:flutter/foundation.dart' as foundation;

class ChatScreen extends StatefulWidget {
  final int contactId;
  final String contactType;
  final String contactName;
  final String? contactPhoto;

  const ChatScreen({
    super.key,
    required this.contactId,
    required this.contactType,
    required this.contactName,
    this.contactPhoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessageService _messageService = MessageService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  late IO.Socket socket; // Variable pour le socket
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmoji = false;
  bool _isOnline = false;

  final String _baseUrl = ApiConstants.socketUrl;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectSocket(); // On lance la connexion Socket au lieu du Timer
  }

  @override
  void dispose() {
    // On déconnecte proprement le socket en quittant l'écran
    socket.dispose(); 
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- CONFIGURATION SOCKET.IO ---
 void _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final int? myId = prefs.getInt('userId'); 
    final String? myRole = prefs.getString('userRole'); 
    
    if (myId == null || myRole == null) return;

    socket = IO.io(_baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect() 
      .build()
    );

    socket.connect();

    socket.onConnect((_) {
      print('✅ Connecté au serveur Socket.io');
      socket.emit('register_chat', {
        'userId': myId,
        'userType': myRole 
      });
    });

    // 4. Écouter les nouveaux messages entrants
    socket.on('receive_message', (data) {
      print('📩 Nouveau message reçu via Socket: $data');
      
      if (mounted) {
        // --- CORRECTION ICI : Conversion en String pour la comparaison ---
        // On convertit tout en String pour éviter les erreurs "5" (String) != 5 (Int)
        final String incomingSenderId = data['id_expediteur'].toString();
        final String currentContactId = widget.contactId.toString();
        
        final String incomingSenderType = data['type_expediteur'].toString();
        final String currentContactType = widget.contactType.toString();

        final String myIdStr = myId.toString();
        final String myRoleStr = myRole.toString();

        // Est-ce que le message vient de la personne à qui je parle ?
        bool isFromContact = (incomingSenderId == currentContactId && incomingSenderType == currentContactType);
        
        // Est-ce que c'est MOI qui l'ai envoyé (depuis un autre appareil ou via l'API) ?
        bool isFromMe = (incomingSenderId == myIdStr && incomingSenderType == myRoleStr);

        print("🧐 Analyse du message :");
        print("   - Reçu de ID: $incomingSenderId (Type: $incomingSenderType)");
        print("   - Contact actuel ID: $currentContactId (Type: $currentContactType)");
        print("   - Est-ce le contact ? $isFromContact");

        if (isFromContact || isFromMe) {
           setState(() {
             _messages.add(data);
             if (isFromContact) _isOnline = true;
           });
           
           // Petit délai pour laisser le temps à la liste de se construire avant de scroller
           Future.delayed(const Duration(milliseconds: 100), () {
             _scrollToBottom();
           });
        }
      }
    });

    socket.onDisconnect((_) => print('❌ Déconnecté du socket'));
  }

  // Fonction pour formater l'heure
  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final DateTime date = DateTime.parse(dateStr).toLocal();
      final String hour = date.hour.toString().padLeft(2, '0');
      final String minute = date.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    } catch (e) {
      return "";
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final msgs = await _messageService.getMessages(
        widget.contactId,
        widget.contactType,
      );

      // Logique "En ligne" basée sur le dernier message (fallback)
      bool onlineStatus = false;
      if (msgs.isNotEmpty) {
        final lastMsg = msgs.last;
        if (lastMsg['id_expediteur'] == widget.contactId) {
             final dateStr = lastMsg['date_envoi'];
             if (dateStr != null) {
               final msgDate = DateTime.parse(dateStr).toLocal();
               if (DateTime.now().difference(msgDate).inMinutes < 5) {
                 onlineStatus = true;
               }
             }
        }
      }

      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
          _isOnline = onlineStatus;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      // 1. Envoyer à l'API (qui va sauvegarder en BDD et émettre le socket à l'autre)
      final response = await _messageService.sendMessage(
        receiverId: widget.contactId,
        receiverType: widget.contactType,
        content: text,
      );
      
      _textController.clear();
      
      // 2. Ajouter manuellement le message à notre liste locale
      // (Car le socket "receive_message" est envoyé au DESTINATAIRE, pas forcément à l'expéditeur sauf si tu l'as codé ainsi)
      // Mais ici, pour être fluide, on l'ajoute direct.
      
      // On peut récupérer l'objet complet si ton API le renvoie, sinon on le construit
      // Supposons que ton API renvoie { message: '...', messageId: 123, dateEnvoi: '...' }
      // Il faut adapter selon ce que ton API `sendMessage` retourne.
      // Si `sendMessage` est void dans ton service, on recharge tout :
      await _loadMessages(); 
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Erreur d'envoi")));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isSending = true);
    try {
      await _messageService.sendMessage(
        receiverId: widget.contactId,
        receiverType: widget.contactType,
        content: "",
        imagePath: image.path,
      );
      await _loadMessages(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erreur d'envoi image")));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String? _getProfileUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return "$_baseUrl$path";
    return "$_baseUrl/uploads/profile/$path";
  }

  String _getMediaUrl(String path) {
    if (path.startsWith('http')) return path;
    if (path.startsWith('/')) return "$_baseUrl$path";
    return "$_baseUrl/$path";
  }

  @override
  Widget build(BuildContext context) {
    final contactPhotoUrl = _getProfileUrl(widget.contactPhoto);

    return Scaffold(
      backgroundColor: const Color(0xFFEFE7DE),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leadingWidth: 20,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const SizedBox(width: 5),
            CircleAvatar(
              radius: 18,
              backgroundImage: contactPhotoUrl != null
                  ? NetworkImage(contactPhotoUrl)
                  : null,
              backgroundColor: Colors.grey[300],
              child: contactPhotoUrl == null
                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isOnline ? "En ligne" : "Hors ligne", 
                    style: TextStyle(
                      color: _isOnline ? const Color.fromARGB(255, 128, 255, 132) : Colors.white70, 
                      fontSize: 12,
                      fontWeight: _isOnline ? FontWeight.bold : FontWeight.normal
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_showEmoji) setState(() => _showEmoji = false);
                FocusScope.of(context).unfocus();
              },
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = _messages[i];
                        final isThem = msg['id_expediteur'] == widget.contactId &&
                            msg['type_expediteur'] == widget.contactType;
                        
                        final dateStr = msg['date_envoi']; 
                        final formattedTime = _formatTime(dateStr);

                        return Align(
                          alignment: isThem
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              color: isThem ? Colors.white : AppColors.primary,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: isThem
                                    ? const Radius.circular(0)
                                    : const Radius.circular(12),
                                bottomRight: isThem
                                    ? const Radius.circular(12)
                                    : const Radius.circular(0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                )
                              ],
                            ),
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (msg['type_contenu'] == 'image' &&
                                      msg['url_media'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 5),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _getMediaUrl(msg['url_media']),
                                          fit: BoxFit.cover,
                                          loadingBuilder:
                                              (ctx, child, progress) =>
                                                  progress == null
                                                      ? child
                                                      : Container(
                                                          height: 150,
                                                          width: 150,
                                                          color: Colors.black12,
                                                          child: const Center(
                                                              child:
                                                                  CircularProgressIndicator()),
                                                        ),
                                          errorBuilder: (ctx, err, stack) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Text(
                                        msg['contenu'] ?? '',
                                        style: TextStyle(
                                          color: isThem
                                              ? Colors.black87
                                              : Colors.white,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                    ),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      formattedTime,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isThem 
                                          ? Colors.grey[600] 
                                          : Colors.white70,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _showEmoji
                                      ? Icons.keyboard
                                      : Icons.emoji_emotions_outlined,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() => _showEmoji = !_showEmoji);
                                  if (_showEmoji) {
                                    FocusScope.of(context).unfocus();
                                  } else {
                                    FocusScope.of(context).requestFocus();
                                  }
                                },
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  onTap: () {
                                    if (_showEmoji)
                                      setState(() => _showEmoji = false);
                                  },
                                  decoration: const InputDecoration(
                                    hintText: "Message",
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  minLines: 1,
                                  maxLines: 6,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.attach_file,
                                    color: Colors.grey[600]),
                                onPressed: () =>
                                    _pickImage(ImageSource.gallery),
                              ),
                              if (_textController.text.isEmpty)
                                IconButton(
                                  icon: Icon(Icons.camera_alt_outlined,
                                      color: Colors.grey[600]),
                                  onPressed: () =>
                                      _pickImage(ImageSource.camera),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _isSending ? null : _sendMessage,
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 24,
                          child: _isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.send,
                                  color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_showEmoji)
                    SizedBox(
                      height: 270,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _textController.text =
                              _textController.text + emoji.emoji;
                          setState(() {});
                        },
                        config: Config(
                          height: 270,
                          checkPlatformCompatibility: true,
                          emojiViewConfig: EmojiViewConfig(
                            columns: 7,
                            emojiSizeMax: 32 *
                                (foundation.defaultTargetPlatform ==
                                        TargetPlatform.iOS
                                    ? 1.30
                                    : 1.0),
                            backgroundColor: const Color(0xFFF2F2F2),
                          ),
                          categoryViewConfig: const CategoryViewConfig(
                            initCategory: Category.RECENT,
                            backgroundColor: Color(0xFFF2F2F2),
                            indicatorColor: AppColors.primary,
                            iconColor: Colors.grey,
                            iconColorSelected: AppColors.primary,
                            backspaceColor: AppColors.primary,
                          ),
                          skinToneConfig: const SkinToneConfig(
                            dialogBackgroundColor: Colors.white,
                            indicatorColor: Colors.grey,
                            enabled: true,
                          ),
                          bottomActionBarConfig:
                              const BottomActionBarConfig(enabled: false),
                          searchViewConfig: const SearchViewConfig(
                              backgroundColor: Color(0xFFF2F2F2)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}