import 'package:flutter/material.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Lista de mensajes de ejemplo
    final List<Map<String, String>> messages = [
      {
        'name': 'Juan Gonzales',
        'message': 'Hola, como estas?',
      },
      {
        'name': 'Paquita Berrios',
        'message': 'Hola, como estas?',
      },
      {
        'name': 'Juan Gonzales',
        'message': 'Hola, como estas?',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            'Mensajería',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: messages.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final message = messages[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              message['name']!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(message['message']!),
            onTap: () {
              // Puedes navegar a una conversación individual aquí
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3F51B5), // Azul tipo Material
        onPressed: () {
          // Acción para crear nuevo mensaje
        },
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}
