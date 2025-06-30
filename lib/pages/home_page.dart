// lib/pages/home_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'calendar_page.dart';
import 'profile_page.dart';
import 'conversation_list_page.dart';
import 'worker_task_detail_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final List<Widget> _pages = [];
  String? nombre;
  String? uid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          nombre = '${data?['nombres'] ?? ''} ${data?['apellidos'] ?? ''}';

          _pages.addAll([
            _buildHomePage(uid!),
            const CalendarPage(),
            const ConversationListPage(),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: const Color(0xFF002F6C),
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          setState(() => _currentIndex = index);
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

  Widget _buildHomePage(String uid) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
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

            final pendientes = tareas
                .where(
                  (t) =>
                      (t['ubicacion']?['estado'] ?? 'pendiente') ==
                      'pendiente',
                )
                .toList();

            final completadas = tareas
                .where(
                  (t) =>
                      (t['ubicacion']?['estado'] ?? 'pendiente') !=
                      'pendiente',
                )
                .toList();

            return ListView(
              children: [
                Text(
                  'Hola, $nombre 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002F6C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estas son tus tareas asignadas:',
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
                // Modificar el map para pasar el documento completo
                ...pendientes.map(
                  (t) => _buildTaskCard(taskDocument: t, isPending: true),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tareas completadas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                // Modificar el map para pasar el documento completo
                ...completadas.map(
                  (t) => _buildTaskCard(taskDocument: t, isPending: false),
                ),
              ],
            );
          },
        ),
      ),
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

  Widget _buildTaskCard({
    required DocumentSnapshot taskDocument,
    required bool isPending,
  }) {
    final actividad = taskDocument['actividad'] ?? 'Actividad Desconocida';
    
    final Timestamp? timestampFecha = taskDocument['fecha'] as Timestamp?;
    final DateTime fecha = timestampFecha?.toDate() ?? DateTime.now(); 

    final estado = taskDocument['ubicacion']?['estado'] ?? 'pendiente';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          isPending ? Icons.assignment : Icons.check_circle,
          color: isPending ? Colors.red.shade600 : Colors.green.shade600,
        ),
        title: Text(actividad, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}\n' // Formatear fecha
          'Estado: $estado', 
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkerTaskDetailPage(
                taskDocument: taskDocument,
              ),
            ),
          );
        },
      ),
    );
  }

}