// lib/pages/conversation_list_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import '../../services/chat_service.dart';
import 'chat/chat_page.dart';
import 'chat/start_new_conversation_page.dart'; 
import '../../models/message.dart'; 

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
          title: const Text('Mensajes'),
          backgroundColor: const Color(0xFF002F6C),
        ),
        body: const Center(child: Text('Debes iniciar sesión para ver tus mensajes.')),
      );
    }

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

          if (snapshot.hasError) {
            print('Error en ConversationListPage: ${snapshot.error}'); // Debugging
            return Center(child: Text('Error al cargar las conversaciones: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tienes conversaciones aún. ¡Inicia una!'));
          }

          final conversations = snapshot.data!;

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final convo = conversations[index];
              final lastMessageType = convo['lastMessageType'] as String? ?? 'text';
              final lastMessageText = convo['lastMessage'] as String? ?? '';
              String displayMessage;

              // Determinar cómo mostrar el último mensaje
              if (lastMessageType == MessageType.image.toString().split('.').last) {
                displayMessage = '🖼️ Imagen';
              } else {
                displayMessage = lastMessageText;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: Theme.of(context).primaryColor),
                  ),
                  title: Text(
                    convo['otherUserName'] ?? 'Usuario Desconocido',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(displayMessage),
                  trailing: convo['timestamp'] != null
                      ? Text(_formatTimestamp(convo['timestamp'] as Timestamp))
                      : const Text(''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          otherUserId: convo['otherUserId'],
                          otherUserName: convo['otherUserName'] ?? 'Usuario',
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
        backgroundColor: const Color(0xFF002F6C), // Color de tu empresa
        tooltip: 'Iniciar nueva conversación',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StartNewConversationPage(),
            ),
          );
        },
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    // Puedes ajustar el formato para mostrar fecha si es un mensaje antiguo
    if (date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year) {
      return DateFormat('HH:mm').format(date); // Hoy: solo hora
    } else {
      return DateFormat('dd/MM').format(date); // Días anteriores: solo día/mes
    }
  }
}