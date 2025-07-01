import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// Importa la página de detalles de la tarea
import 'worker_task_detail_page.dart'; // Asegúrate de que esta ruta es correcta

// Extensión para capitalizar la primera letra de un String
extension StringCasingExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
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
          const SnackBar(
              content: Text(
                  'Error: No hay usuario autenticado. Por favor, inicia sesión.')),
        );
      });
    }
  }

  /// Método para obtener las tareas de Firestore para un rango de fechas dado (generalmente un mes)
  /// Las fechas se normalizan a UTC para asegurar consistencia con TableCalendar.
  Future<void> _getEventsForRange(DateTime month) async {
    if (_currentUserId == null) {
      debugPrint('DEBUG: _currentUserId es nulo. No se pueden cargar tareas.');
      return;
    }

    final startOfMonth = DateTime.utc(month.year, month.month, 1);
    final endOfMonth = DateTime.utc(month.year, month.month + 1, 0, 23, 59, 59);

    debugPrint(
        'DEBUG: Cargando tareas para el usuario $_currentUserId desde $startOfMonth hasta $endOfMonth');

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('tareas_asignadas')
          .where('usuario_asignado', isEqualTo: _currentUserId)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      debugPrint('DEBUG: Se encontraron ${querySnapshot.docs.length} documentos.');

      final Map<DateTime, List<DocumentSnapshot>> newEvents = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['fecha'] as Timestamp?;

        if (timestamp != null) {
          final date = timestamp.toDate();
          // Normalizamos la fecha a UTC para que TableCalendar la interprete correctamente
          final normalizedDate = DateTime.utc(date.year, date.month, date.day);

          debugPrint(
              '  DEBUG: Tarea: ${data['actividad']}, Fecha: $normalizedDate, Estado: ${data['ubicacion']?['estado']}');

          if (newEvents[normalizedDate] == null) {
            newEvents[normalizedDate] = [];
          }
          newEvents[normalizedDate]!.add(doc);
        } else {
          debugPrint('  DEBUG: Documento sin timestamp de fecha: ${doc.id}');
        }
      }

      if (mounted) {
        setState(() {
          _events.clear();
          _events.addAll(newEvents);
          // Asegúrate de que _selectedDay no sea nulo al llamar a _getEventsForDay
          _selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
          debugPrint('DEBUG: _events ahora tiene ${_events.length} entradas.');
          debugPrint(
              'DEBUG: _selectedEvents para el día seleccionado tiene ${_selectedEvents.length} elementos.');
        });
      }
    } catch (e) {
      debugPrint('ERROR: Error al cargar tareas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tareas: $e')),
        );
      }
    }
  }

  /// Método auxiliar para obtener la lista de eventos para un día específico.
  /// Normaliza el día de entrada para que coincida con las claves del mapa _events.
  List<DocumentSnapshot> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
    return _events[normalizedDay] ?? [];
  }

  /// Constructor para el marcador de eventos en el calendario.
  /// La lógica determina el color del marcador basado en los estados de las tareas del día.
  Widget _buildEventsMarker(DateTime date, List events) {
    bool hasPending = false;
    bool hasInProgress = false;
    bool hasCompleted = false;
    bool hasCancelled = false;

    for (var event in events) {
      final data = (event as DocumentSnapshot).data() as Map<String, dynamic>;
      final estado = (data['ubicacion']?['estado'] as String? ?? '').toLowerCase();

      debugPrint('  DEBUG: Marcador para $date, Evento ID: ${event.id}, Estado: $estado');

      if (estado == 'pendiente') {
        hasPending = true;
      } else if (estado == 'en progreso') {
        hasInProgress = true;
      } else if (estado == 'completada') {
        hasCompleted = true;
      } else if (estado == 'cancelada') {
        hasCancelled = true;
      }
    }

    Color markerColor = Colors.grey; // Color por defecto

    // Prioridad de colores: Pendiente (rojo) > En Progreso (naranja) > Cancelada (gris oscuro) > Completada (verde)
    if (hasPending) {
      markerColor = Colors.red;
    } else if (hasInProgress) {
      markerColor = Colors.orange;
    } else if (hasCancelled) {
      markerColor = Colors.black45;
    } else if (hasCompleted) {
      markerColor = Colors.green;
    }

    debugPrint('  DEBUG: Marcador para $date, Color final: $markerColor');

    return Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
      ),
      width: 8.0,
      height: 8.0,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
    );
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
                'Calendario de Tareas',
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
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _selectedEvents =
                          _getEventsForDay(selectedDay); // Actualiza eventos del día
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  // Cuando el usuario cambia de mes, actualiza _focusedDay y carga nuevas tareas
                  if (!isSameDay(_focusedDay, focusedDay)) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                    _getEventsForRange(focusedDay);
                  }
                },
                eventLoader: (day) {
                  final events = _getEventsForDay(day);
                  // debugPrint('DEBUG: eventLoader para $day retorna ${events.length} eventos.');
                  return events;
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    if (events.isNotEmpty) {
                      // debugPrint('DEBUG: markerBuilder llamado para $date con ${events.length} eventos.');
                      return Positioned(
                        right: 1,
                        bottom: 1,
                        child: _buildEventsMarker(date, events),
                      );
                    }
                    // debugPrint('DEBUG: markerBuilder: No hay eventos para $date.');
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
                  // markerDecoration es un fallback, _buildEventsMarker lo sobrescribe
                  markerDecoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
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
                  leftChevronIcon:
                      Icon(Icons.chevron_left, color: Color(0xFF002F6C), size: 30),
                  rightChevronIcon:
                      Icon(Icons.chevron_right, color: Color(0xFF002F6C), size: 30),
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
                          final actividad =
                              taskData['actividad'] ?? 'Actividad no especificada';
                          final timestampFecha = taskData['fecha'] as Timestamp?;
                          final fechaDisplay = timestampFecha != null
                              ? DateFormat('dd/MM/yyyy').format(timestampFecha.toDate())
                              : 'Fecha N/A';
                          final estado = (taskData['ubicacion']?['estado'] as String? ?? 'desconocido')
                              .capitalizeFirst();
                          final horaDisplay = timestampFecha != null
                              ? DateFormat('HH:mm').format(timestampFecha.toDate())
                              : 'Hora N/A';

                          Color statusColor;
                          bool isEditable = true; // Nueva variable para controlar la editabilidad

                          switch (estado.toLowerCase()) {
                            case 'pendiente':
                              statusColor = Colors.red;
                              break;
                            case 'en progreso':
                              statusColor = Colors.orange;
                              break;
                            case 'completada':
                              statusColor = Colors.green;
                              isEditable = false; // No editable si está completada
                              break;
                            case 'cancelada':
                              statusColor = Colors.black45;
                              isEditable = false; // No editable si está cancelada
                              break;
                            default:
                              statusColor = Colors.blue; // Color por defecto
                              break;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            child: InkWell(
                              // Deshabilita el onTap si la tarea no es editable
                              onTap: isEditable
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              WorkerTaskDetailPage(taskDocument: taskDoc),
                                        ),
                                      ).then((_) {
                                        // Recarga las tareas cuando se regresa de la página de detalles
                                        _getEventsForRange(_focusedDay);
                                        // Vuelve a cargar los eventos para el día seleccionado por si el estado cambió
                                        setState(() {
                                          _selectedEvents = _getEventsForDay(_selectedDay!);
                                        });
                                      });
                                    }
                                  : null, // Si no es editable, onTap es null
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Indicador de color del estado
                                    Container(
                                      width: 8,
                                      height: 60,
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
                                              decoration: !isEditable
                                                  ? TextDecoration.lineThrough
                                                  : null, // Tachado si no es editable
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Estado: $estado',
                                              style:
                                                  TextStyle(fontSize: 14, color: Colors.grey[700])),
                                          Text('Fecha: $fechaDisplay',
                                              style:
                                                  TextStyle(fontSize: 14, color: Colors.grey[700])),
                                          Text('Hora: $horaDisplay',
                                              style:
                                                  TextStyle(fontSize: 14, color: Colors.grey[700])),
                                        ],
                                      ),
                                    ),
                                    // Muestra el icono de flecha solo si es editable
                                    if (isEditable)
                                      const Icon(Icons.arrow_forward_ios,
                                          color: Colors.grey, size: 18),
                                    // Opcional: Podrías mostrar un icono diferente si no es editable, por ejemplo:
                                    // else
                                    //   const Icon(Icons.lock, color: Colors.grey, size: 18),
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