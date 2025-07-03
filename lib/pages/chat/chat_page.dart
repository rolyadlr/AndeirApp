import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../services/chat_service.dart';
import '../../models/message.dart';

class TypingStatusProvider with ChangeNotifier {
  bool _isTyping = false;
  String? _otherUserTypingId;

  bool get isTyping => _isTyping;
  String? get otherUserTypingId => _otherUserTypingId;

  void setTyping(bool value, String? otherUserId) {
    if (_isTyping != value || _otherUserTypingId != otherUserId) {
      _isTyping = value;
      _otherUserTypingId = otherUserId;
      notifyListeners();
    }
  }
}

class ChatPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? chatRoomId;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.chatRoomId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  late String _actualChatRoomId;
  bool _isLoadingChatRoom = true;
  Stream<Map<String, dynamic>>? _typingStatusStream;
  bool _isOtherUserTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.dispose();
    if (currentUser != null && !_isLoadingChatRoom) {
      _chatService.updateTypingStatus(
        _actualChatRoomId,
        currentUser!.uid,
        false,
      );
    }
    super.dispose();
  }

  Future<void> _initializeChatRoom() async {
    if (currentUser == null) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes iniciar sesión para acceder al chat.'),
          ),
        );
      }
      return;
    }

    String generatedChatRoomId;
    if (widget.chatRoomId != null) {
      generatedChatRoomId = widget.chatRoomId!;
    } else {
      List<String> ids = [currentUser!.uid, widget.otherUserId];
      ids.sort();
      generatedChatRoomId = ids.join("_");
    }

    setState(() {
      _actualChatRoomId = generatedChatRoomId;
      _isLoadingChatRoom = false;
      _typingStatusStream = _chatService.getTypingStatusStream(
        _actualChatRoomId,
      );
    });

    _typingStatusStream?.listen((typingUsers) {
      if (mounted) {
        setState(() {
          _isOtherUserTyping = typingUsers[widget.otherUserId] == true;
        });
      }
    });
  }

  void _sendMessage() async {
    if (currentUser == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      await _chatService.sendMessage(
        senderId: currentUser!.uid,
        receiverId: widget.otherUserId,
        messageText: text,
      );
      _messageController.clear();
      _scrollToBottom();
      _chatService.updateTypingStatus(
        _actualChatRoomId,
        currentUser!.uid,
        false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    if (currentUser == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final File imageFile = File(pickedFile.path);

    try {
      await _chatService.sendImageMessage(
        senderId: currentUser!.uid,
        receiverId: widget.otherUserId,
        imageFile: imageFile,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar la imagen: ${e.toString()}')),
        );
      }
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

  void _onMessageChanged() {
    if (currentUser == null || _isLoadingChatRoom) return;
    bool isCurrentlyTyping = _messageController.text.isNotEmpty;
    _chatService.updateTypingStatus(
      _actualChatRoomId,
      currentUser!.uid,
      isCurrentlyTyping,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingChatRoom) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Cargando chat...',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF002F6C),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002F6C),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isOtherUserTyping)
              const Text(
                'Escribiendo...',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessages(
                currentUser!.uid,
                widget.otherUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error al cargar mensajes: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Di algo para empezar la conversación.'),
                  );
                }

                final messages = snapshot.data!;
                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 10.0,
                  ),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUser!.uid;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isMe ? const Color(0xFF002F6C) : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg.type == MessageType.image &&
                                msg.imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: CachedNetworkImage(
                                    imageUrl: msg.imageUrl!,
                                    placeholder:
                                        (context, url) =>
                                            const CircularProgressIndicator(),
                                    errorWidget:
                                        (context, url, error) =>
                                            const Icon(Icons.error),
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(msg.timestamp.toDate()),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                    ),
                    onTap: _scrollToBottom,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.image,
                    color: Color(0xFF002F6C),
                    size: 28,
                  ),
                  onPressed: _sendImage,
                  tooltip: 'Enviar imagen',
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF002F6C),
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
