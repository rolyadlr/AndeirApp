// lib/pages/Administrador/admin_conversations_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';
import '../chat/chat_page.dart';
import '../chat/start_new_conversation_page.dart';

class AdminConversationsPage extends StatefulWidget {
  const AdminConversationsPage({super.key});

  @override
  State<AdminConversationsPage> createState() => _AdminConversationsPageState();
}

class _AdminConversationsPageState extends State<AdminConversationsPage> {
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mensajes de Administrador'),
          backgroundColor: const Color.fromARGB(255, 67, 104, 151),
        ),
        body: const Center(
          child: Text('Debes iniciar sesión para ver los mensajes del administrador.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversaciones del Administrador'),
        backgroundColor: const Color(0xFF002F6C),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getUserConversations(currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar las conversaciones.'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay conversaciones aún para el administrador.'));
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
                title: Text(convo['otherUserName'] ?? 'Usuario'),
                subtitle: Text(convo['lastMessage'] ?? ''),
                trailing: convo['timestamp'] != null
                    ? Text(_formatTimestamp(convo['timestamp']))
                    : const Text(''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        otherUserId: convo['otherUserId'],
                        otherUserName: convo['otherUserName'],
                        chatRoomId: convo['chatRoomId'],
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
        tooltip: 'Iniciar nueva conversación',
        onPressed: () {
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
