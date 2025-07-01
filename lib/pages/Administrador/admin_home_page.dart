// lib/pages/Administrador/AdminHomePage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'asignacion_tareas_page.dart';
import 'admin_conversations_page.dart';
import 'Admin_profile_page.dart';
import 'edit_task_page.dart';
import 'view_task_report_page.dart'; 

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
      const AdminConversationsPage(),
      const AdminMiCuentaPage(),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Method to delete a task
  Future<void> _deleteTask(DocumentSnapshot taskDocument) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar esta tarea?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('tareas_asignadas').doc(taskDocument.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarea eliminada correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar la tarea: $e')),
          );
        }
      }
    }
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

        final pendientes = tareas
            .where((t) => (t['ubicacion']?['estado'] ?? 'pendiente') == 'pendiente')
            .toList();
        final enProgreso = tareas
            .where((t) => (t['ubicacion']?['estado'] ?? 'pendiente') == 'en progreso')
            .toList();
        final completadas = tareas
            .where((t) => (t['ubicacion']?['estado'] ?? 'pendiente') == 'completada')
            .toList();
        final canceladas = tareas
            .where((t) => (t['ubicacion']?['estado'] ?? 'pendiente') == 'cancelada')
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
                _buildTaskCounter(
                  pendientes.length,
                  enProgreso.length,
                  completadas.length,
                  canceladas.length,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tareas pendientes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                ...pendientes.map((t) => _buildTaskCard(t)),
                const SizedBox(height: 20),
                const Text(
                  'Tareas en progreso',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                ...enProgreso.map((t) => _buildTaskCard(t)),
                const SizedBox(height: 20),
                const Text(
                  'Tareas completadas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                ...completadas.map((t) => _buildTaskCard(t)),
                const SizedBox(height: 20),
                const Text(
                  'Tareas canceladas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 10),
                ...canceladas.map((t) => _buildTaskCard(t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskCounter(
      int pendientes, int enProgreso, int completadas, int canceladas) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCounterBox('Pendientes', pendientes, Colors.red.shade700),
            _buildCounterBox('En Progreso', enProgreso, Colors.orange.shade700),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCounterBox('Completadas', completadas, Colors.green.shade700),
            _buildCounterBox('Canceladas', canceladas, Colors.grey.shade700),
          ],
        ),
      ],
    );
  }

  Widget _buildCounterBox(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
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
      ),
    );
  }

  Widget _buildTaskCard(QueryDocumentSnapshot tarea) {
    final actividad = tarea['actividad'] ?? 'Sin actividad';

    final Timestamp? timestampFecha = tarea['fecha'] as Timestamp?;
    final DateTime fecha = timestampFecha?.toDate() ?? DateTime.now();

    final estado = tarea['ubicacion']?['estado'] ?? 'pendiente';
    final usuarioId = tarea['usuario_asignado'];

    IconData statusIcon;
    Color statusColor;
    switch (estado) {
      case 'pendiente':
        statusIcon = Icons.assignment;
        statusColor = Colors.red.shade600;
        break;
      case 'en progreso':
        statusIcon = Icons.hourglass_empty;
        statusColor = Colors.orange.shade600;
        break;
      case 'completada':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green.shade600;
        break;
      case 'cancelada':
        statusIcon = Icons.cancel;
        statusColor = Colors.grey.shade600;
        break;
      default:
        statusIcon = Icons.assignment;
        statusColor = Colors.grey;
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(usuarioId)
          .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(title: Text("Cargando usuario..."));
        }

        final usuario = userSnapshot.data;
        final nombre = usuario != null
            ? '${usuario['nombres'] ?? ''} ${usuario['apellidos'] ?? ''}'
            : 'Usuario desconocido';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              statusIcon,
              color: statusColor,
            ),
            title: Text(
              actividad,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Asignado a: $nombre\n'
              'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}\n'
              'Estado: $estado',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showTaskOptions(context, tarea, estado);
            },
          ),
        );
      },
    );
  }

  void _showTaskOptions(
      BuildContext context, DocumentSnapshot taskDocument, String estado) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Ver Detalles de la Tarea'),
                onTap: () {
                  Navigator.pop(bc); // Close the bottom sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewTaskReportPage(
                        taskDocument: taskDocument,
                      ),
                    ),
                  );
                },
              ),
              if (estado != 'completada' && estado != 'cancelada')
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar Tarea'),
                  onTap: () {
                    Navigator.pop(bc); // Close the bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTaskPage(
                          taskDocument: taskDocument,
                        ),
                      ),
                    );
                  },
                ),
              if (estado == 'completada' || estado == 'cancelada')
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Editar Tarea (Solo para completadas/canceladas)'),
                  onTap: () {
                    Navigator.pop(bc); // Close the bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTaskPage(
                          taskDocument: taskDocument,
                        ),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar Tarea', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(bc); // Close the bottom sheet
                  _deleteTask(taskDocument);
                },
              ),
            ],
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