// lib/services/chat_service.dart
import 'dart:io'; // Para manejar archivos de imagen

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Nuevo: Para Firebase Storage
import '../models/message.dart'; // Asegúrate de que el path sea correcto

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; // Nuevo: Instancia de Storage

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Stream de todos los usuarios registrados, excluyendo al usuario actual.
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
      }).where((user) => user['uid'] != _auth.currentUser?.uid).toList(); // Filtra al usuario actual
    });
  }

  /// Envía un mensaje de texto.
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String messageText,
  }) async {
    // Generar el ID del chat room
    String chatRoomId = _getChatRoomId(senderId, receiverId);

    // Crear un nuevo mensaje
    Message newMessage = Message(
      senderId: senderId,
      receiverId: receiverId,
      text: messageText,
      timestamp: Timestamp.now(),
      type: MessageType.text, // Tipo de mensaje: texto
    );

    await _sendMessageToFirestore(chatRoomId, newMessage);
  }

  /// Envía un mensaje de imagen.
  Future<void> sendImageMessage({
    required String senderId,
    required String receiverId,
    required File imageFile,
  }) async {
    String chatRoomId = _getChatRoomId(senderId, receiverId);
    String? imageUrl;

    try {
      // Subir la imagen a Firebase Storage
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      Reference ref = _storage.ref().child('chat_images').child(chatRoomId).child(fileName);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      imageUrl = await snapshot.ref.getDownloadURL();

      // Crear el mensaje de imagen
      Message newMessage = Message(
        senderId: senderId,
        receiverId: receiverId,
        text: 'Imagen', // Texto descriptivo para la imagen
        timestamp: Timestamp.now(),
        imageUrl: imageUrl,
        type: MessageType.image, // Tipo de mensaje: imagen
      );

      await _sendMessageToFirestore(chatRoomId, newMessage);
    } catch (e) {
      print('Error al enviar la imagen: $e');
      rethrow; // Re-lanza el error para ser manejado en la UI
    }
  }

  /// Función auxiliar para guardar el mensaje en Firestore y actualizar el chat room.
  Future<void> _sendMessageToFirestore(String chatRoomId, Message message) async {
    try {
      // Guardar el mensaje en el chat room
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(message.toMap());

      // Actualizar la última actividad del chat room
      await _firestore.collection('chat_rooms').doc(chatRoomId).set(
        {
          'participants': [message.senderId, message.receiverId]..sort(), // Asegura participantes ordenados
          'lastMessage': message.type == MessageType.text ? message.text : '🖼️ Imagen',
          'lastMessageSenderId': message.senderId,
          'timestamp': Timestamp.now(),
          'lastMessageType': message.type.toString().split('.').last, // Nuevo: Tipo del último mensaje
        },
        SetOptions(merge: true), // Merge para no sobrescribir otros campos
      );
    } catch (e) {
      print('Error al enviar el mensaje a Firestore: $e');
      rethrow;
    }
  }

  /// Obtiene los mensajes para un chat específico.
  Stream<List<Message>> getMessages(String userId1, String userId2) {
    String chatRoomId = _getChatRoomId(userId1, userId2);

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

  /// Obtiene las conversaciones para el usuario actual.
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
        final userDoc = await _firestore.collection('usuarios').doc(otherUserId).get();
        final userData = userDoc.data();

        if (userData != null) {
          conversations.add({
            'chatRoomId': doc.id,
            'otherUserId': otherUserId,
            'otherUserName': '${userData['nombres'] ?? ''} ${userData['apellidos'] ?? ''}',
            'lastMessage': data['lastMessage'] ?? 'Sin mensajes',
            'timestamp': data['timestamp'] ?? Timestamp.now(),
            'lastMessageType': data['lastMessageType'] ?? 'text',
          });
        }
      }
      return conversations;
    });
  }

  /// Método auxiliar para generar el ID del chat room de forma consistente.
  String _getChatRoomId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort(); // Ordenar los IDs para crear un chat room ID consistente
    return ids.join("_");
  }

  // --- Funcionalidad de "Escribiendo..." (Typing Indicator) ---

  /// Actualiza el estado de "escribiendo" del usuario en un chat room.
  Future<void> updateTypingStatus(String chatRoomId, String userId, bool isTyping) async {
    try {
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'typingUsers.$userId': isTyping, // Usa un mapa anidado para el estado de cada usuario
      });
    } catch (e) {
      print('Error al actualizar el estado de escritura: $e');
    }
  }

  /// Obtiene un stream del estado de "escribiendo" para un chat room.
  Stream<Map<String, dynamic>> getTypingStatusStream(String chatRoomId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots().map((snapshot) {
      final data = snapshot.data();
      return (data?['typingUsers'] as Map<String, dynamic>?) ?? {};
    });
  }
}