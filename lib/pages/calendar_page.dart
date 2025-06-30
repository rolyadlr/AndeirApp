import 'package:andeir_app/utils/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Necesario para formatear fechas si lo deseas, o simplemente para depuración

// Importa la página de detalles de la tarea para la navegación
import 'worker_task_detail_page.dart'; // Asegúrate que esta ruta es correcta

// Extensión para capitalizar la primera letra de un String
extension CalendarStringExtension on String { // Renombrado
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _currentUserId;

  // Mapa para almacenar los eventos (tareas) por fecha.
  // La clave es DateTime (solo fecha, normalizada a UTC para TableCalendar)
  // El valor es una lista de DocumentSnapshot de Firestore
  final Map<DateTime, List<DocumentSnapshot>> _events = {};

  // Lista de eventos (tareas) para el día actualmente seleccionado en el calendario
  List<DocumentSnapshot> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _selectedDay = _focusedDay; // Inicialmente selecciona el día actual
    if (_currentUserId != null) {
      // Carga las tareas para el mes inicial
      _getEventsForRange(_focusedDay);
    } else {
      // Si no hay usuario, mostrar mensaje o redirigir
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No hay usuario autenticado. Por favor, inicia sesión.')),
        );
      });
    }
  }

  // Método para obtener las tareas de Firestore para un rango de fechas dado (generalmente un mes)
Future<void> _getEventsForRange(DateTime month) async {
  if (_currentUserId == null) {
    print('DEBUG: _currentUserId es nulo. No se pueden cargar tareas.');
    return;
  }

  final startOfMonth = DateTime.utc(month.year, month.month, 1);
  final endOfMonth = DateTime.utc(month.year, month.month + 1, 0, 23, 59, 59);

  print('DEBUG: Cargando tareas para el usuario $_currentUserId desde $startOfMonth hasta $endOfMonth');

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('tareas_asignadas')
        .where('usuario_asignado', isEqualTo: _currentUserId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    print('DEBUG: Se encontraron ${querySnapshot.docs.length} documentos.');

    final Map<DateTime, List<DocumentSnapshot>> newEvents = {};
    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['fecha'] as Timestamp?;

      if (timestamp != null) {
        final date = timestamp.toDate();
        final normalizedDate = DateTime.utc(date.year, date.month, date.day);

        // Debugging the date and event data
        print('  DEBUG: Tarea: ${data['actividad']}, Fecha: $normalizedDate, Estado: ${data['ubicacion']?['estado']}');

        if (newEvents[normalizedDate] == null) {
          newEvents[normalizedDate] = [];
        }
        newEvents[normalizedDate]!.add(doc);
      } else {
        print('  DEBUG: Documento sin timestamp de fecha: ${doc.id}');
      }
    }

    setState(() {
      _events.clear();
      _events.addAll(newEvents);
      _selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
      print('DEBUG: _events ahora tiene ${_events.length} entradas.');
      print('DEBUG: _selectedEvents para el día seleccionado tiene ${_selectedEvents.length} elementos.');
    });
  } catch (e) {
    print('ERROR: Error al cargar tareas: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar tareas: $e')),
      );
    }
  }
}

  // Método auxiliar para obtener la lista de eventos para un día específico
  List<DocumentSnapshot> _getEventsForDay(DateTime day) {
    // Normaliza el día de entrada para que coincida con las claves del mapa _events
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  // Constructor para el marcador de eventos en el calendario
  Widget _buildEventsMarker(DateTime date, List events) {
    // Lógica para determinar el color del marcador basado en los estados de las tareas
    bool hasPending = false;
    bool hasInProgress = false;
    bool hasCompleted = false;
    bool hasCancelled = false;

    for (var event in events) {
      final data = (event as DocumentSnapshot).data() as Map<String, dynamic>;
      // Accede al estado y conviértelo a minúsculas para la comparación
      final estado = (data['ubicacion']?['estado'] as String? ?? '').toLowerCase();

      print('  DEBUG: Marcador para $date, Evento ID: ${event.id}, Estado: $estado'); // Debugging for each event

      if (estado == 'pendiente') {
        hasPending = true;
        // No break aquí si quieres que un día con múltiples tareas de diferentes estados
        // tenga el color de la tarea más "crítica" (ej. pendiente)
      } else if (estado == 'en progreso') {
        hasInProgress = true;
      } else if (estado == 'completada') {
        hasCompleted = true;
      } else if (estado == 'cancelada') {
        hasCancelled = true;
      }
    }

    Color markerColor = Colors.grey; // Default color if no specific state matched

    // Prioridad de colores: Pendiente > En Progreso > Cancelada > Completada
    if (hasPending) {
      markerColor = Colors.red;
    } else if (hasInProgress) {
      markerColor = Colors.orange;
    } else if (hasCancelled) { // Podrías poner cancelada antes de completada o viceversa
      markerColor = Colors.black45;
    } else if (hasCompleted) {
      markerColor = Colors.green;
    }

    print('  DEBUG: Marcador para $date, Color final: $markerColor'); // Debugging final color

    return Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
      ),
      width: 8.0, // Puedes aumentar esto temporalmente para verlos mejor, ej. 15.0
      height: 8.0, // Puedes aumentar esto temporalmente para verlos mejor, ej. 15.0
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
    );
  }

  // Función auxiliar para formatear la fecha a un formato legible
  String _formatFecha(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // Función auxiliar para formatear la hora si la tienes como un String
  // Si la hora también viene de un Timestamp, necesitarías ajustar esto.
  String _formatHora(String? hora) {
    return hora ?? 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calendario de Tareas', // Cambiado el título para ser más descriptivo
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002F6C), // Color de tu empresa
                ),
              ),
              const SizedBox(height: 16),
              // Calendario
              TableCalendar(
                focusedDay: _focusedDay,
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _selectedEvents = _getEventsForDay(selectedDay); // Actualiza eventos del día
                  });
                },
                onPageChanged: (focusedDay) {
                  // Cuando el usuario cambia de mes, actualiza _focusedDay y carga nuevas tareas
                  _focusedDay = focusedDay;
                  _getEventsForRange(focusedDay);
                },
                  eventLoader: (day) {
                      final events = _getEventsForDay(day);
                      // print('DEBUG: eventLoader para $day retorna ${events.length} eventos.'); // Otra print útil
                      return events;
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isNotEmpty) {
                          // print('DEBUG: markerBuilder llamado para $date con ${events.length} eventos.'); // Confirma que se llama
                          return Positioned(
                            right: 1,
                            bottom: 1,
                            child: _buildEventsMarker(date, events),
                          );
                        }
                        // print('DEBUG: markerBuilder: No hay eventos para $date.'); // Si no hay eventos
                        return null;
                      },
                    ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Color(0xFF002F6C), // Azul de tu empresa para el día actual
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Color(0xFF3F51B5), // Otro tono de azul o morado para el día seleccionado
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.red, // Este es un fallback, el _buildEventsMarker lo sobrescribe
                    shape: BoxShape.circle,
                  ),
                  // Estilos para los textos de los días
                  weekendTextStyle: TextStyle(color: Colors.black87),
                  outsideDaysVisible: false, // Oculta días de meses anteriores/siguientes
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002F6C), // Color de tu empresa
                  ),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFF002F6C), size: 30),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFF002F6C), size: 30),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              // Título para la lista de tareas del día seleccionado
              Text(
                _selectedDay == null
                    ? 'Selecciona un día'
                    : 'Tareas para el ${DateFormat('dd MMMM yyyy', 'es').format(_selectedDay!)}:',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002F6C),
                ),
              ),  
              const SizedBox(height: 12),
              // Lista de Tareas para el día seleccionado
              Expanded(
                child: _selectedEvents.isEmpty
                    ? Center(
                        child: Text(
                          _selectedDay == null
                              ? 'Aún no has seleccionado un día.'
                              : 'No hay tareas asignadas para este día.',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _selectedEvents.length,
                        itemBuilder: (context, index) {
                          final taskDoc = _selectedEvents[index];
                          final taskData = taskDoc.data() as Map<String, dynamic>;

                          // Extrae los datos con valores por defecto si son nulos
                          final actividad = taskData['actividad'] ?? 'Actividad no especificada';
                          final timestampFecha = taskData['fecha'] as Timestamp?;
                          final fechaDisplay = timestampFecha != null ? _formatFecha(timestampFecha) : 'Fecha N/A';
                          final estado = (taskData['ubicacion']?['estado'] as String? ?? 'desconocido').capitalizeFirst();
                          final horaDisplay = timestampFecha != null ? DateFormat('HH:mm').format(timestampFecha.toDate()) : 'Hora N/A';


                          Color statusColor;
                          switch (estado.toLowerCase()) { 
                            case 'pendiente':
                              statusColor = Colors.red;
                              break;
                            case 'en progreso':
                              statusColor = Colors.orange;
                              break;
                            case 'completada':
                              statusColor = Colors.green;
                              break;
                            case 'cancelada':
                              statusColor = Colors.black45;
                              break;
                            default:
                              statusColor = Colors.blue; // Color por defecto
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            child: InkWell(
                              onTap: () {
                                // Navega a la página de detalles de la tarea
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WorkerTaskDetailPage(taskDocument: taskDoc),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Indicador de color del estado
                                    Container(
                                      width: 8,
                                      height: 60, // Ajusta la altura según tus necesidades
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            actividad,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: statusColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Estado: $estado', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                          Text('Fecha: $fechaDisplay', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                          Text('Hora: $horaDisplay', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                          // Puedes añadir más detalles como dirección si la tienes en la tarea
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}