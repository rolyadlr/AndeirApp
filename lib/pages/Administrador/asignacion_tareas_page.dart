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
    final snapshot = await FirebaseFirestore.instance.collection('usuarios').get();
    setState(() {
      trabajadores = snapshot.docs;
      trabajadoresFiltrados = trabajadores;
    });
  }

  void obtenerActividades() async {
    final snapshot = await FirebaseFirestore.instance.collection('actividades').get();
    setState(() {
      actividades = snapshot.docs.map((doc) => doc['nombre'].toString()).toList();
    });
  }

  void filtrarTrabajadores(String query) {
    final filtrados = trabajadores.where((doc) {
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

    // *** CAMBIO CLAVE AQUÍ: Guarda la fecha como Timestamp ***
    await FirebaseFirestore.instance.collection('tareas_asignadas').add({
      'usuario_asignado': trabajadorSeleccionado!.id,
      'actividad': actividadSeleccionada,
      'fecha': Timestamp.fromDate(_selectedDay!), // <-- CAMBIO HECHO AQUÍ
      'ubicacion': {
        'lat': ubicacionSeleccionada!.latitude,
        'lng': ubicacionSeleccionada!.longitude,
        'estado': 'pendiente', 
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Asignar Tarea')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _buscarController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre o DNI',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: filtrarTrabajadores,
                ),
              ),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: trabajadoresFiltrados.length,
                  itemBuilder: (context, index) {
                    final trabajador = trabajadoresFiltrados[index];
                    return ListTile(
                      title: Text('${trabajador['nombres']} ${trabajador['apellidos']}'),
                      subtitle: Text('DNI: ${trabajador['dni']}'),
                      trailing: trabajadorSeleccionado?.id == trabajador.id
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        setState(() {
                          trabajadorSeleccionado = trabajador;
                        });
                      },
                    );
                  },
                ),
              ),
              if (trabajadorSeleccionado != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: actividadSeleccionada,
                        items: actividades.map((actividad) {
                          return DropdownMenuItem(
                            value: actividad,
                            child: Text(actividad),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            actividadSeleccionada = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Actividad',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Selecciona la fecha',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                        calendarStyle: const CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Selecciona una ubicación en el mapa',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 200,
                        child: FlutterMap(
                          options: MapOptions(
                            center: const LatLng(-12.0464, -77.0428), // Lima por defecto
                            zoom: 13,
                            onTap: (tapPosition, point) {
                              setState(() {
                                ubicacionSeleccionada = point;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                                  )
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: guardarTarea,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: const Text('Guardar Tarea', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}