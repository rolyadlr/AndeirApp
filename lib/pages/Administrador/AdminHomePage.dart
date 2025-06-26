// lib/pages/Administrador/AdminHomePage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'asignacion_tareas_page.dart';
import 'admin_conversations_page.dart'; // <--- IMPORTACIÓN DE LA NUEVA PÁGINA
import 'Admin_profile_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _buildDashboardPage(),
      const AsignacionTareasPage(),
      const AdminConversationsPage(), // <--- CAMBIADO A LA NUEVA PÁGINA DE CHAT PARA ADMIN
      const AdminMiCuentaPage(),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildDashboardPage() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('tareas_asignadas')
              .orderBy('fecha', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No hay tareas asignadas'));
        }

        final tareas = snapshot.data!.docs;

        final pendientes =
            tareas
                .where(
                  (t) =>
                      (t['ubicacion']?['estado'] ?? 'pendiente') == 'pendiente',
                )
                .toList();
        final completadas =
            tareas
                .where(
                  (t) =>
                      (t['ubicacion']?['estado'] ?? 'pendiente') != 'pendiente',
                )
                .toList();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                const Text(
                  'Panel de Tareas',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002F6C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tareas asignadas a los técnicos',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                _buildTaskCounter(pendientes.length, completadas.length),
                const SizedBox(height: 20),
                const Text(
                  'Tareas pendientes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                ...pendientes.map((t) => _buildTaskCard(t, true)),
                const SizedBox(height: 20),
                const Text(
                  'Tareas completadas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                ...completadas.map((t) => _buildTaskCard(t, false)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskCounter(int pendientes, int completadas) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCounterBox('Pendientes', pendientes, Colors.red.shade700),
        _buildCounterBox(
          'Completadas',
          completadas,
          const Color.fromARGB(255, 121, 118, 118),
        ),
      ],
    );
  }

  Widget _buildCounterBox(String label, int count, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(QueryDocumentSnapshot tarea, bool isPending) {
    final actividad = tarea['actividad'] ?? 'Sin actividad';
    final fecha = DateTime.tryParse(tarea['fecha'] ?? '') ?? DateTime.now();
    final estado = tarea['ubicacion']?['estado'] ?? 'pendiente';
    final usuarioId = tarea['usuario_asignado'];

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('usuarios')
              .doc(usuarioId)
              .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(title: Text("Cargando usuario..."));
        }

        final usuario = userSnapshot.data;
        final nombre =
            usuario != null
                ? '${usuario['nombres']} ${usuario['apellidos']}'
                : 'Usuario desconocido';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              isPending ? Icons.assignment : Icons.check_circle,
              color: isPending ? Colors.red.shade600 : Colors.green.shade600,
            ),
            title: Text(
              actividad,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Asignado a: $nombre\n'
              'Fecha: ${fecha.day}/${fecha.month}/${fecha.year}\n'
              'Estado: $estado',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: const Color(0xFF002F6C),
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Asignación',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: 'Mensajes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}