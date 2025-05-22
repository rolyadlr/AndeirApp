import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'asignacion_tareas_page.dart';
import 'Admin_messages_page.dart';
import 'Admin_profile_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.addAll([
      _buildDashboardPage(),
      const AsignacionTareasPage(),
      const MensajeriaPage(),
      const AdminMiCuentaPage(),
    ]);
  }

  Widget _buildDashboardPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
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

        return ListView.builder(
          itemCount: tareas.length,
          itemBuilder: (context, index) {
            final tarea = tareas[index];
            final actividad = tarea['actividad'] ?? 'Sin actividad';
            final fecha = DateTime.tryParse(tarea['fecha'] ?? '') ?? DateTime.now();
            final estado = tarea['ubicacion']?['estado'] ?? 'pendiente';
            final usuarioId = tarea['usuario_asignado'];

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuarios').doc(usuarioId).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(title: Text("Cargando usuario..."));
                }

                final usuario = userSnapshot.data;
                final nombre = usuario != null
                    ? '${usuario['nombres']} ${usuario['apellidos']}'
                    : 'Usuario desconocido';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(actividad),
                    subtitle: Text(
                      'Asignado a: $nombre\n'
                      'Fecha: ${fecha.day}/${fecha.month}/${fecha.year}\n'
                      'Estado: $estado',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Pantalla de detalles próximamente")),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Administrador')),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Asignación',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Mensajería',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Mi cuenta',
          ),
        ],
      ),
    );
  }
}
