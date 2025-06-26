// lib/pages/chat/start_new_conversation_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import 'chat_page.dart';

class StartNewConversationPage extends StatefulWidget {
  const StartNewConversationPage({super.key});

  @override
  State<StartNewConversationPage> createState() => _StartNewConversationPageState();
}

class _StartNewConversationPageState extends State<StartNewConversationPage> {
  final ChatService _chatService = ChatService();
  final User? currentUser = FirebaseAuth.instance.currentUser;

@override
Widget build(BuildContext context) {
  if (currentUser == null) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Nueva Conversación'),
        backgroundColor: const Color(0xFF002F6C),
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
            return const Center(child: Text('No hay usuarios disponibles.'));
          }

          final users = snapshot.data!;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              // No mostrar al usuario actual en la lista para chatear consigo mismo
              if (user['uid'] == currentUser!.uid) {
                return const SizedBox.shrink();
              }
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text('${user['nombres']} ${user['apellidos']}'),
                subtitle: Text(user['rol'] ?? 'Sin rol'), // Muestra el rol
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        otherUserId: user['uid'],
                        otherUserName: '${user['nombres']} ${user['apellidos']}',
                        // No pasamos chatRoomId aquí, ChatPage lo generará si es una nueva conversación
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}