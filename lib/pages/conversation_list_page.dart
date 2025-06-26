// lib/pages/conversation_list_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';
import 'chat/chat_page.dart';
import 'chat/start_new_conversation_page.dart'; 

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Mensajes'),
          backgroundColor: Color(0xFF002F6C),
        ),
        body: Center(child: Text('Debes iniciar sesión para ver tus mensajes.')),
      );
    }


    // Agrega esta línea para depuración
    print('Current User UID: ${currentUser?.uid}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tus Conversaciones'),
        backgroundColor: const Color(0xFF002F6C),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getUserConversations(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tienes conversaciones aún.'));
          }

          final conversations = snapshot.data!;

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final convo = conversations[index];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(convo['otherUserName']),
                subtitle: Text(convo['lastMessage']),
                trailing: Text(_formatTimestamp(convo['timestamp'])),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        otherUserId: convo['otherUserId'],
                        otherUserName: convo['otherUserName'],
                        chatRoomId: convo['chatRoomId'], // Pasamos el ID del chat room
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3F51B5),
        onPressed: () {
          // Navegar a una página para iniciar una nueva conversación
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StartNewConversationPage(),
            ),
          );
        },
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}