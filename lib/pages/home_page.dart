// lib/pages/home_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Importaciones de tus otras páginas
import 'calendar_page.dart';
import 'profile_page.dart';
import 'conversation_list_page.dart';
import 'worker_task_detail_page.dart';
// Importa la extensión de String para capitalizar.

/// HomePage es el widget principal que muestra las tareas asignadas al usuario
/// y proporciona la navegación inferior.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0; // Índice de la pestaña seleccionada en la barra de navegación.
  String? _userName; // Almacena el nombre completo del usuario.
  String? _userUid; // Almacena el UID del usuario actual.
  bool _isLoading = true; // Indica si los datos del usuario están cargándose.

  // Lista de widgets para las diferentes pestañas de navegación.
  // Se inicializa en _fetchUserData una vez que el UID está disponible.
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Carga los datos del usuario al iniciar el estado.
  }

  /// Obtiene los datos del usuario autenticado (nombre y UID) desde Firebase.
  /// También inicializa la lista de páginas de navegación.
  Future<void> _fetchUserData() async {
    _userUid = FirebaseAuth.instance.currentUser?.uid; // Obtener el UID del usuario actual.

    if (_userUid != null) {
      try {
        // Consultar el documento del usuario en Firestore.
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(_userUid).get();

        if (doc.exists) {
          final data = doc.data();
          // Combinar nombres y apellidos para formar el nombre completo.
          _userName = '${data?['nombres'] ?? ''} ${data?['apellidos'] ?? ''}';

          // Inicializar las páginas después de obtener el UID.
          _pages.addAll([
            _buildHomePage(_userUid!), // La página de inicio requiere el UID.
            const CalendarPage(),
            const ConversationListPage(),
            const ProfilePage(),
          ]);
        } else {
          // Manejar caso donde el documento del usuario no existe.
          print('Error: El documento del usuario con UID $_userUid no existe.');
          // Podrías redirigir al usuario o mostrar un mensaje de error más amigable.
        }
      } catch (e) {
        // Capturar y registrar cualquier error durante la obtención de datos.
        print('Error al obtener datos del usuario: $e');
      } finally {
        // Asegurarse de que _isLoading se establezca en false, incluso si hay un error.
        setState(() => _isLoading = false);
      }
    } else {
      // Si no hay usuario autenticado, también dejar de cargar.
      setState(() => _isLoading = false);
      print('Advertencia: No hay usuario autenticado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un indicador de carga mientras se obtienen los datos del usuario.
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Si _pages está vacío (ej. no se pudo obtener el UID o los datos del usuario),
    // muestra un mensaje de error o una pantalla predeterminada.
    if (_pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error de Carga')),
        body: const Center(
          child: Text('No se pudo cargar la información de las páginas. Intenta de nuevo más tarde.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _pages[_currentIndex], // Muestra la página correspondiente al índice actual.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.red.shade700,
        unselectedItemColor: const Color(0xFF002F6C),
        backgroundColor: Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          // Actualiza el índice de la pestaña seleccionada al tocar un ítem.
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

  /// Construye la vista de la página de inicio, mostrando las tareas del usuario.
  Widget _buildHomePage(String uid) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<QuerySnapshot>(
          // Escucha los cambios en la colección 'tareas_asignadas' para el usuario actual.
          stream: FirebaseFirestore.instance
              .collection('tareas_asignadas')
              .where('usuario_asignado', isEqualTo: uid)
              .orderBy('fecha', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Muestra un indicador de carga mientras se obtienen los datos.
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Muestra un mensaje si no hay datos o la lista está vacía.
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No tienes tareas asignadas.'));
            }

            final tareas = snapshot.data!.docs;

            // Filtra las tareas por estado
            final List<DocumentSnapshot> pendientes = [];
            final List<DocumentSnapshot> enProgreso = [];
            final List<DocumentSnapshot> completadas = [];
            final List<DocumentSnapshot> canceladas = [];

            for (var tarea in tareas) {
              final data = tarea.data() as Map<String, dynamic>?;
              final estado = data?['ubicacion']?['estado'] ?? 'pendiente'; // Valor por defecto
              switch (estado) {
                case 'pendiente':
                  pendientes.add(tarea);
                  break;
                case 'en progreso':
                  enProgreso.add(tarea);
                  break;
                case 'completada':
                  completadas.add(tarea);
                  break;
                case 'cancelada':
                  canceladas.add(tarea);
                  break;
                default:
                  // Si hay algún estado inesperado, se considera pendiente
                  pendientes.add(tarea);
              }
            }

            return ListView(
              children: [
                Text(
                  'Hola, $_userName 👋', // Muestra el nombre del usuario.
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
                // Muestra los contadores de tareas.
                _buildTaskCounters(pendientes.length, enProgreso.length, completadas.length, canceladas.length),
                const SizedBox(height: 20),

                // Secciones de tareas por estado
                _buildTaskSection(
                  title: 'Tareas Pendientes',
                  tasks: pendientes,
                  isEditable: true, // Las pendientes son editables
                  emptyMessage: 'No tienes tareas pendientes.',
                ),
                _buildTaskSection(
                  title: 'Tareas En Progreso',
                  tasks: enProgreso,
                  isEditable: true, // Las en progreso son editables
                  emptyMessage: 'No tienes tareas en progreso.',
                ),
                _buildTaskSection(
                  title: 'Tareas Completadas',
                  tasks: completadas,
                  isEditable: false, // Las completadas no son editables
                  emptyMessage: 'No tienes tareas completadas.',
                ),
                _buildTaskSection(
                  title: 'Tareas Canceladas',
                  tasks: canceladas,
                  isEditable: false, // Las canceladas no son editables
                  emptyMessage: 'No tienes tareas canceladas.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Construye los contadores para los cuatro estados de tareas.
  Widget _buildTaskCounters(int pendientes, int enProgreso, int completadas, int canceladas) {
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
            _buildCounterBox('Canceladas', canceladas, Colors.grey.shade600),
          ],
        ),
      ],
    );
  }

  /// Construye una caja individual para mostrar el conteo de tareas.
  Widget _buildCounterBox(String label, int count, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.45, // Ajusta el ancho para dos columnas
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

  /// Construye una sección de tareas con un título y una lista de tarjetas.
  Widget _buildTaskSection({
    required String title,
    required List<DocumentSnapshot> tasks,
    required bool isEditable,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                emptyMessage,
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ...tasks.map(
            (t) => _buildTaskCard(taskDocument: t, isEditable: isEditable),
          ),
      ],
    );
  }

  /// Construye una tarjeta para mostrar los detalles de una tarea individual.
  Widget _buildTaskCard({
    required DocumentSnapshot taskDocument,
    required bool isEditable,
  }) {
    final data = taskDocument.data() as Map<String, dynamic>?;

    final actividad = data?['actividad'] ?? 'Actividad Desconocida';
    final Timestamp? timestampFecha = data?['fecha'] as Timestamp?;
    final DateTime fecha = timestampFecha?.toDate() ?? DateTime.now();
    final estado = data?['ubicacion']?['estado'] ?? 'pendiente';

    Color iconColor;
    IconData iconData;

    switch (estado) {
      case 'pendiente':
        iconColor = Colors.red.shade600;
        iconData = Icons.assignment;
        break;
      case 'en progreso':
        iconColor = Colors.orange.shade600;
        iconData = Icons.play_circle_fill_outlined;
        break;
      case 'completada':
        iconColor = Colors.green.shade600;
        iconData = Icons.check_circle;
        break;
      case 'cancelada':
        iconColor = Colors.grey.shade600;
        iconData = Icons.cancel;
        break;
      default:
        iconColor = Colors.blueGrey;
        iconData = Icons.help_outline;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          iconData,
          color: iconColor,
        ),
        title: Text(actividad, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}\n'
          'Estado: ${estado.toString().capitalizeFirsthome()}', // Usar la extensión para capitalizar
        ),
        trailing: isEditable
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : const Icon(Icons.visibility, size: 16), // Ícono de ojo para ver detalles
        onTap: isEditable
            ? () {
                // Permite navegar y editar solo si la tarea es editable
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerTaskDetailPage(
                      taskDocument: taskDocument,
                      isEditable: true, // Se pasa true porque es editable
                    ),
                  ),
                );
              }
            : () {
                // Solo permite ver los detalles si la tarea no es editable
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkerTaskDetailPage(
                      taskDocument: taskDocument,
                      isEditable: false, // Se pasa false para deshabilitar edición
                    ),
                  ),
                );
              },
      ),
    );
  }
}
extension WorkerTaskStringExtension on String {
  String capitalizeFirsthome() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}