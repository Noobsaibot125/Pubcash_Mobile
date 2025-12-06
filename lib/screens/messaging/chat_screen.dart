import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:pubcash_mobile/utils/api_constants.dart';
import '../../services/message_service.dart';
import '../../utils/colors.dart';
import 'package:flutter/foundation.dart' as foundation; // Pour la config web/mobile

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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur d'envoi")));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur d'envoi image")));
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
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: contactPhotoUrl != null ? NetworkImage(contactPhotoUrl) : null,
              backgroundColor: Colors.grey[200],
              child: contactPhotoUrl == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.contactName, style: const TextStyle(color: Colors.black, fontSize: 16), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = _messages[i];
                        final isThem = msg['id_expediteur'] == widget.contactId && msg['type_expediteur'] == widget.contactType;

                        return Align(
                          alignment: isThem ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isThem ? Colors.white : AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
                            ),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (msg['type_contenu'] == 'image' && msg['url_media'] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(_getMediaUrl(msg['url_media']),
                                      loadingBuilder: (ctx, child, progress) => progress == null ? child : const SizedBox(height: 100, width: 100, child: Center(child: CircularProgressIndicator())),
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image),
                                    ),
                                  )
                                else
                                  Text(msg['contenu'] ?? '', style: TextStyle(color: isThem ? Colors.black87 : Colors.white, fontSize: 15)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.grey),
                        onPressed: () {
                          setState(() => _showEmoji = !_showEmoji);
                          if (_showEmoji) {
                            FocusScope.of(context).unfocus();
                          } else {
                            FocusScope.of(context).requestFocus();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: Colors.grey),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey),
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(25)),
                          child: TextField(
                            controller: _textController,
                            onTap: () {
                              if (_showEmoji) setState(() => _showEmoji = false);
                            },
                            decoration: const InputDecoration(hintText: "Message...", border: InputBorder.none),
                            minLines: 1,
                            maxLines: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _isSending ? null : _sendMessage,
                        child: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          radius: 22,
                          child: _isSending
                            ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),

                  // CONFIGURATION EMOJI PICKER CORRIGÉE (V4.x)
                  if (_showEmoji)
                    SizedBox(
                      height: 250,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          _textController.text = _textController.text + emoji.emoji;
                        },
                        config: Config(
                          height: 250,
                          checkPlatformCompatibility: true,
                          
                          // 1. Emoji View Config
                          emojiViewConfig: EmojiViewConfig(
                            columns: 7,
                            emojiSizeMax: 32 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.30 : 1.0),
                            verticalSpacing: 0,
                            horizontalSpacing: 0,
                            gridPadding: EdgeInsets.zero,
                            recentsLimit: 28,
                            buttonMode: ButtonMode.MATERIAL,
                          ),
                          
                          // 2. Category View Config
                          categoryViewConfig: CategoryViewConfig(
                            initCategory: Category.RECENT,
                            backgroundColor: const Color(0xFFF2F2F2),
                            indicatorColor: AppColors.primary,
                            iconColor: Colors.grey,
                            iconColorSelected: AppColors.primary,
                            backspaceColor: AppColors.primary,
                            tabIndicatorAnimDuration: kTabScrollDuration,
                            categoryIcons: const CategoryIcons(),
                          ),
                          
                          // 3. Skin Tone Config (CORRIGÉ ICI)
                          skinToneConfig: const SkinToneConfig(
                            dialogBackgroundColor: Colors.white, // Renommé: dialogBgColor -> dialogBackgroundColor
                            indicatorColor: Colors.grey,
                            enabled: true, 
                          ),
                          
                          // 4. Autres Configs
                          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                          searchViewConfig: const SearchViewConfig(backgroundColor: Color(0xFFF2F2F2)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}