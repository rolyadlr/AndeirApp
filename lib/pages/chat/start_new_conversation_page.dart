// lib/pages/chat/start_new_conversation_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import 'chat_page.dart';

class StartNewConversationPage extends StatefulWidget {
  const StartNewConversationPage({super.key});

  @override
  State<StartNewConversationPage> createState() =>
      _StartNewConversationPageState();
}

class _StartNewConversationPageState extends State<StartNewConversationPage> {
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        // Solo AppBar modificado
        appBar: AppBar(
          backgroundColor: const Color(0xFF002F6C),
          title: const Text(
            'Iniciar Nueva Conversación',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),

        body: const Center(
          child: Text('Debes iniciar sesión para iniciar una conversación.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Nueva Conversación'),
        backgroundColor: const Color(0xFF002F6C),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatService.getUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No hay usuarios disponibles para chatear.'),
            );
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              // _chatService.getUsersStream() ya filtra al usuario actual,
              // pero esta verificación es una doble seguridad.
              if (user['uid'] == currentUser!.uid) {
                return const SizedBox.shrink();
              }
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  title: Text(
                    '${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(user['rol'] ?? 'Sin rol'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => ChatPage(
                              otherUserId: user['uid'],
                              otherUserName:
                                  '${user['nombres'] ?? ''} ${user['apellidos'] ?? ''}',
                              // No pasamos chatRoomId aquí, ChatPage lo generará si es una nueva conversación
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
    );
  }
}
