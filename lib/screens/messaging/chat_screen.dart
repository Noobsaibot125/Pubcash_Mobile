import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmoji = false;
  final String _baseUrl = ApiConstants.socketUrl;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final msgs = await _messageService.getMessages(
        widget.contactId,
        widget.contactType,
      );
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _messageService.sendMessage(
        receiverId: widget.contactId,
        receiverType: widget.contactType,
        content: text,
      );
      _textController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Erreur d'envoi")));
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
      print("Erreur upload image: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erreur d'envoi image")));
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
                  const Text(
                    "En ligne",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        // ACTIONS SUPPRIMÉES ICI (Appel, Vidéo, Menu)
        actions: [], 
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

                        return Align(
                          alignment: isThem
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(4),
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
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                                                                  CircularProgressIndicator())),
                                          errorBuilder: (ctx, err, stack) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
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
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          // ZONE DE SAISIE CORRIGÉE
          // Utilisation de SafeArea pour gérer automatiquement le bas de l'écran (barre système Android / Home bar iOS)
          SafeArea(
            child: Container(
              // Suppression du padding bottom fixe (25) qui causait le problème
              padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8), 
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
                  
                  // PICKER EMOJI
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
                          categoryViewConfig: CategoryViewConfig(
                            initCategory: Category.RECENT,
                            backgroundColor: const Color(0xFFF2F2F2),
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