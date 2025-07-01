// lib/models/message.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image } 

class Message {
  final String senderId;
  final String receiverId;
  final String text;
  final Timestamp timestamp;
  final String? imageUrl; 
  final MessageType type; 

  Message({
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.imageUrl, 
    this.type = MessageType.text, 
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    // Asegúrate de manejar el caso donde 'type' podría no existir en mensajes antiguos
    final typeString = map['type'] as String? ?? 'text';
    MessageType messageType;
    try {
      messageType = MessageType.values.firstWhere((e) => e.toString().split('.').last == typeString);
    } catch (e) {
      messageType = MessageType.text; // Fallback si el tipo no es reconocido
    }

    return Message(
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      text: map['text'] as String,
      timestamp: map['timestamp'] as Timestamp,
      imageUrl: map['imageUrl'] as String?, // Puede ser nulo
      type: messageType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'timestamp': timestamp,
      'imageUrl': imageUrl,
      'type': type.toString().split('.').last, // Guarda el enum como String
    };
  }
}