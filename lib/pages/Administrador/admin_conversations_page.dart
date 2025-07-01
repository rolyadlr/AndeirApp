// lib/pages/Administrador/admin_conversations_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha/hora

import '../../services/chat_service.dart';
import '../chat/chat_page.dart';
import '../chat/start_new_conversation_page.dart';
import '../../models/message.dart'; // Asegúrate de importar Message

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
          backgroundColor: const Color(0xFF002F6C), // Usar color de tu empresa
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
            print('Error en AdminConversationsPage: ${snapshot.error}'); // Debugging
            return Center(child: Text('Error al cargar las conversaciones: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay conversaciones aún para el administrador.'));
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