import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';

class AsignacionTareasPage extends StatefulWidget {
  const AsignacionTareasPage({super.key});

  @override
  State<AsignacionTareasPage> createState() => _AsignacionTareasPageState();
}

class _AsignacionTareasPageState extends State<AsignacionTareasPage> {
  List<DocumentSnapshot> trabajadores = [];
  List<DocumentSnapshot> trabajadoresFiltrados = [];
  DocumentSnapshot? trabajadorSeleccionado;

  List<String> actividades = [];
  String? actividadSeleccionada;

  LatLng? ubicacionSeleccionada;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final TextEditingController _buscarController = TextEditingController();

  @override
  void initState() {
    super.initState();
    obtenerTrabajadores();
    obtenerActividades();
  }

  void obtenerTrabajadores() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('usuarios').get();
    setState(() {
      trabajadores = snapshot.docs;
      trabajadoresFiltrados = trabajadores;
    });
  }

  void obtenerActividades() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('actividades').get();
    setState(() {
      actividades =
          snapshot.docs.map((doc) => doc['nombre'].toString()).toList();
    });
  }

  void filtrarTrabajadores(String query) {
    final filtrados =
        trabajadores.where((doc) {
          final nombres = doc['nombres'].toString().toLowerCase();
          final dni = doc['dni'].toString();
          return nombres.contains(query.toLowerCase()) || dni.contains(query);
        }).toList();

    setState(() {
      trabajadoresFiltrados = filtrados;
    });
  }

  void guardarTarea() async {
    if (trabajadorSeleccionado == null ||
        ubicacionSeleccionada == null ||
        actividadSeleccionada == null ||
        _selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('tareas_asignadas').add({
      'usuario_asignado': trabajadorSeleccionado!.id,
      'actividad': actividadSeleccionada,
      'fecha': Timestamp.fromDate(_selectedDay!),
      'ubicacion': {
        'lat': ubicacionSeleccionada!.latitude,
        'lng': ubicacionSeleccionada!.longitude,
        'estado': 'pendiente',
      },
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tarea asignada correctamente')),
    );

    setState(() {
      trabajadorSeleccionado = null;
      actividadSeleccionada = null;
      ubicacionSeleccionada = null;
      _selectedDay = null;
      _buscarController.clear();
      trabajadoresFiltrados = trabajadores;
    });
  }

  @override
  Widget build(BuildContext context) {
    final azulIntenso = const Color(0xFF002E6D);
    final rojoOscuro = const Color(0xFFB71C1C);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: azulIntenso,
        title: const Text(
          'Asignar Tarea',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _buscarController,
                decoration: InputDecoration(
                  labelText: 'Buscar por nombre o DNI',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: filtrarTrabajadores,
              ),
              const SizedBox(height: 16),
              ...trabajadoresFiltrados.map((trabajador) {
                final isSelected = trabajadorSeleccionado?.id == trabajador.id;
                return Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? rojoOscuro : azulIntenso,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.black54),
                    title: Text(
                      '${trabajador['nombres']} ${trabajador['apellidos']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'DNI: ${trabajador['dni']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    trailing:
                        isSelected
                            ? Icon(Icons.check_circle, color: rojoOscuro)
                            : null,
                    onTap: () {
                      setState(() {
                        trabajadorSeleccionado = trabajador;
                      });
                    },
                  ),
                );
              }).toList(),
              if (trabajadorSeleccionado != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: actividadSeleccionada,
                  isExpanded: true,
                  items:
                      actividades.map((actividad) {
                        IconData icono;
                        if (actividad.toLowerCase().contains('limpieza')) {
                          icono = Icons.cleaning_services;
                        } else if (actividad.toLowerCase().contains(
                          'reparación',
                        )) {
                          icono = Icons.build;
                        } else if (actividad.toLowerCase().contains(
                          'supervisión',
                        )) {
                          icono = Icons.supervised_user_circle;
                        } else {
                          icono = Icons.work_outline;
                        }
                        return DropdownMenuItem(
                          value: actividad,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icono, size: 18, color: Colors.black54),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  actividad,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      actividadSeleccionada = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Selecciona una actividad',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecciona la fecha',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: rojoOscuro,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    todayDecoration: BoxDecoration(
                      border: Border.all(color: azulIntenso, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: azulIntenso,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Selecciona una ubicación en el mapa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      center: const LatLng(-12.0464, -77.0428),
                      zoom: 13,
                      onTap: (tapPosition, point) {
                        setState(() {
                          ubicacionSeleccionada = point;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      if (ubicacionSeleccionada != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: ubicacionSeleccionada!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: guardarTarea,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Tarea'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rojoOscuro,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
