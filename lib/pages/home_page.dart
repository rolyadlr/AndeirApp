import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_page.dart';
import 'calendar_page.dart';
import 'profile_page.dart';
import 'messages_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [];

  String? nombre;
  String? correo;
  String? telefono;
  bool _isLoading = true;
  String? uid;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          nombre = '${data?['nombres'] ?? ''} ${data?['apellidos'] ?? ''}';
          correo = data?['correo'] ?? 'No especificado';
          telefono = data?['celular'] ?? 'No especificado';

          _pages.addAll([
            _buildHomePage(uid!),
            const CalendarPage(),
            const MessagesPage(),
            const ProfilePage(),
          ]);

          setState(() => _isLoading = false);
        }
      } catch (e) {
        print('Error al obtener datos del usuario: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.indigoAccent,
        unselectedItemColor: Colors.black54,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
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
            label: 'Mensajería',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Mi cuenta',
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage(String uid) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tareas_asignadas')
              .where('usuario_asignado', isEqualTo: uid)
              .orderBy('fecha', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No tienes tareas asignadas.'));
            }

            final tareas = snapshot.data!.docs;

            final pendientes = tareas.where((t) =>
              (t['ubicacion']?['estado'] ?? 'pendiente') == 'pendiente'
            ).toList();

            final completadas = tareas.where((t) =>
              (t['ubicacion']?['estado'] ?? 'pendiente') != 'pendiente'
            ).toList();

            return ListView(
              children: [
                Text(
                  '¡Bienvenido, $nombre!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3F51B5),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Correo: $correo'),
                Text('Teléfono: $telefono'),
                const SizedBox(height: 20),

                const Text(
                  'Tareas pendientes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...pendientes.map((t) => _buildTaskCard(
                  isPending: true,
                  title: t['actividad'] ?? 'Actividad',
                  subtitle: _formatFecha(t['fecha']),
                  icon: Icons.assignment,
                )),

                const SizedBox(height: 20),
                const Text(
                  'Avisos recientes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...completadas.map((t) => _buildTaskCard(
                  isPending: false,
                  title: t['actividad'] ?? 'Actividad',
                  subtitle: _formatFecha(t['fecha']),
                  icon: Icons.event_note,
                )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required bool isPending,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: isPending ? Colors.orange : Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  String _formatFecha(String fechaStr) {
    try {
      final fecha = DateTime.parse(fechaStr);
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (_) {
      return 'Fecha desconocida';
    }
  }
}
