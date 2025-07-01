// lib/pages/Administrador/user_role_management_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
class UserRoleManagementPage extends StatefulWidget {
  const UserRoleManagementPage({super.key});

  @override
  State<UserRoleManagementPage> createState() => _UserRoleManagementPageState();
}

class _UserRoleManagementPageState extends State<UserRoleManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Color azulIndigo = const Color(0xFF002F6C);
  final Color rojo = const Color(0xFFE53935);
  final Color verde = Colors.green; 
  @override
  Widget build(BuildContext context) {
    final String? currentAdminUid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Roles de Usuario', style: TextStyle(color: Colors.white)),
        backgroundColor: azulIndigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;
              final nombres = userData['nombres'] ?? 'N/A';
              final apellidos = userData['apellidos'] ?? 'N/A';
              final rol = userData['rol'] ?? 'trabajador'; 

              if (userId == currentAdminUid) {
                return const SizedBox.shrink(); 
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$nombres $apellidos',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Text('Rol: ${rol}'),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => _toggleUserRole(userId, rol),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulIndigo,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(rol == 'administrador' ? 'Hacer Trabajador' : 'Hacer Administrador'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleUserRole(String userId, String currentRole) async {
    final newRole = currentRole == 'administrador' ? 'trabajador' : 'administrador';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cambiar Rol a ${newRole}'),
        content: Text('¿Estás seguro de que quieres cambiar el rol de este usuario a "${newRole}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('usuarios').doc(userId).update({'rol': newRole});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol de usuario actualizado a ${newRole}.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cambiar el rol: $e')),
        );
      }
    }
  }
}