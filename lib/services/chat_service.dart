// lib/services/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart'; 

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
 
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('usuarios').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return {
          'uid': doc.id,
          'nombres': user['nombres'] ?? 'Nombre Desconocido',
          'apellidos': user['apellidos'] ?? '',
          'email': user['email'] ?? '',
          'rol': user['rol'] ?? 'trabajador', 
        };
      }).toList();
    });
  }

  // Enviar un mensaje
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String messageText,
  }) async {
    // ID del chat room (combinación de IDs de usuario para asegurar unicidad)
    List<String> ids = [senderId, receiverId];
    ids.sort(); // Ordenar los IDs para crear un chat room ID consistente
    String chatRoomId = ids.join("_");

    // Crear un nuevo mensaje
    Message newMessage = Message(
      senderId: senderId,
      receiverId: receiverId,
      text: messageText,
      timestamp: Timestamp.now(),
    );

    // Guardar el mensaje en el chat room
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .add(newMessage.toMap());

    // Actualizar la última actividad del chat room (opcional pero útil para ordenar)
    await _firestore.collection('chat_rooms').doc(chatRoomId).set(
      {
        'participants': ids,
        'lastMessage': messageText,
        'lastMessageSenderId': senderId,
        'timestamp': Timestamp.now(),
      },
      SetOptions(merge: true), // Merge para no sobrescribir otros campos
    );
  }

  // Obtener mensajes para un chat específico
  Stream<List<Message>> getMessages(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    String chatRoomId = ids.join("_");

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Message.fromMap(doc.data());
      }).toList();
    });
  }

  // Obtener conversaciones para el usuario actual
  Stream<List<Map<String, dynamic>>> getUserConversations(String userId) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> conversations = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants']);
        final otherUserId = participants.firstWhere((id) => id != userId);

        // Obtener los datos del otro usuario
        final userDoc =
            await _firestore.collection('usuarios').doc(otherUserId).get();
        final userData = userDoc.data();

        if (userData != null) {
          conversations.add({
            'chatRoomId': doc.id,
            'otherUserId': otherUserId,
            'otherUserName':
                '${userData['nombres'] ?? ''} ${userData['apellidos'] ?? ''}',
            'lastMessage': data['lastMessage'] ?? 'Sin mensajes',
            'timestamp': data['timestamp'] ?? Timestamp.now(),
          });
        }
      }
      return conversations;
    });
  }
}