import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/chat_service.dart';
import '../chat/chat_page.dart';
import '../chat/start_new_conversation_page.dart';
import '../../models/message.dart';

class AdminConversationsPage extends StatefulWidget {
  const AdminConversationsPage({super.key});

  @override
  State<AdminConversationsPage> createState() => _AdminConversationsPageState();
}

class _AdminConversationsPageState extends State<AdminConversationsPage> {
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  final azulIntenso = const Color(0xFF002F6C);
  final rojoOscuro = const Color(0xFFB71C1C);

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: azulIntenso,
          title: const Text(
            'Mensajes',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('Debes iniciar sesión para ver los mensajes.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: azulIntenso,
        title: const Text(
          'Mensajes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getUserConversations(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar las conversaciones: ${snapshot.error}',
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No hay conversaciones aún para el administrador.'),
            );
          }

          final conversations = snapshot.data!;

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final convo = conversations[index];
              final lastMessageType =
                  convo['lastMessageType'] as String? ?? 'text';
              final lastMessageText = convo['lastMessage'] as String? ?? '';
              String displayMessage;

              if (lastMessageType ==
                  MessageType.image.toString().split('.').last) {
                displayMessage = '🖼️ Imagen enviada';
              } else {
                displayMessage = lastMessageText;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: azulIntenso.withOpacity(0.1),
                    child: Icon(Icons.person, color: azulIntenso),
                  ),
                  title: Text(
                    convo['otherUserName'] ?? 'Usuario Desconocido',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      displayMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (convo['timestamp'] != null)
                        Text(
                          _formatTimestamp(convo['timestamp'] as Timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 4),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ChatPage(
                              otherUserId: convo['otherUserId'],
                              otherUserName:
                                  convo['otherUserName'] ?? 'Usuario',
                              chatRoomId: convo['chatRoomId'],
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: rojoOscuro,
        tooltip: 'Iniciar nueva conversación',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StartNewConversationPage()),
          );
        },
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    if (date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year) {
      return DateFormat('HH:mm').format(date);
    } else {
      return DateFormat('dd/MM').format(date);
    }
  }
}
