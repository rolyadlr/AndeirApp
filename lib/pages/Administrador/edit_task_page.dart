import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';

class EditTaskPage extends StatefulWidget {
  final DocumentSnapshot taskDocument;

  const EditTaskPage({super.key, required this.taskDocument});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores y variables para la edición
  String? _selectedTrabajadorId;
  String? _selectedActividad;
  LatLng? _selectedLocation;
  DateTime? _selectedDate;
  String? _selectedEstado; // Nuevo campo para el estado

  List<DocumentSnapshot> _trabajadores = [];
  List<String> _actividades = [];
  List<String> _estados = ['pendiente', 'en progreso', 'completada', 'cancelada']; // Estados posibles

  final MapController _mapController = MapController();

  // Bandera para asegurar que el mapa se mueva solo una vez al inicio
  bool _initialMapMoved = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchDropdownData();
  }

  // Carga los datos iniciales de la tarea para pre-rellenar los campos
  void _loadInitialData() {
    final data = widget.taskDocument.data() as Map<String, dynamic>;

    _selectedTrabajadorId = data['usuario_asignado'];
    _selectedActividad = data['actividad'];
    if (data['ubicacion'] != null && data['ubicacion']['lat'] != null && data['ubicacion']['lng'] != null) {
      _selectedLocation = LatLng(data['ubicacion']['lat'], data['ubicacion']['lng']);
    }
    
    if (data['fecha'] is Timestamp) {
      _selectedDate = (data['fecha'] as Timestamp).toDate();
    } else if (data['fecha'] is String) {
      _selectedDate = DateTime.tryParse(data['fecha']);
    }

    _selectedEstado = data['ubicacion']?['estado'] ?? 'pendiente';
  }

  // Obtener datos para los Dropdowns (trabajadores y actividades)
  void _fetchDropdownData() async {
    // Obtener trabajadores
    final trabajadoresSnapshot = await _firestore.collection('usuarios').get();
    setState(() {
      _trabajadores = trabajadoresSnapshot.docs;
    });

    // Obtener actividades
    final actividadesSnapshot = await _firestore.collection('actividades').get();
    setState(() {
      _actividades = actividadesSnapshot.docs.map((doc) => doc['nombre'].toString()).toList();
    });
  }

  // Actualizar la tarea en Firestore
  Future<void> _updateTask() async {
    if (_selectedTrabajadorId == null ||
        _selectedActividad == null ||
        _selectedLocation == null ||
        _selectedDate == null ||
        _selectedEstado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    try {
      await _firestore.collection('tareas_asignadas').doc(widget.taskDocument.id).update({
        'usuario_asignado': _selectedTrabajadorId,
        'actividad': _selectedActividad,
        'fecha': Timestamp.fromDate(_selectedDate!),
        'ubicacion': {
          'lat': _selectedLocation!.latitude,
          'lng': _selectedLocation!.longitude,
          'estado': _selectedEstado,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea actualizada correctamente')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la tarea: $e')),
      );
    }
  }

  // Eliminar la tarea de Firestore
  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
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
        await _firestore.collection('tareas_asignadas').doc(widget.taskDocument.id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea eliminada correctamente')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la tarea: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Buscar el nombre completo del trabajador seleccionado para mostrarlo
    String? selectedTrabajadorName;
    if (_selectedTrabajadorId != null && _trabajadores.isNotEmpty) {
      try {
        final trabajadorDoc = _trabajadores.firstWhere((doc) => doc.id == _selectedTrabajadorId);
        final userData = trabajadorDoc.data() as Map<String, dynamic>;
        selectedTrabajadorName = '${userData['nombres'] ?? ''} ${userData['apellidos'] ?? ''}'.trim();
      } catch (e) {
        selectedTrabajadorName = 'Trabajador no encontrado';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Tarea'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trabajador Asignado:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedTrabajadorId,
                decoration: const InputDecoration(labelText: 'Seleccionar Trabajador'),
                items: _trabajadores.map((trabajador) {
                  final data = trabajador.data() as Map<String, dynamic>;
                  final name = '${data['nombres'] ?? ''} ${data['apellidos'] ?? ''}'.trim();
                  return DropdownMenuItem(
                    value: trabajador.id,
                    child: Text(name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTrabajadorId = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              const Text('Actividad:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedActividad,
                decoration: const InputDecoration(labelText: 'Seleccionar Actividad'),
                items: _actividades.map((actividad) {
                  return DropdownMenuItem(
                    value: actividad,
                    child: Text(actividad),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedActividad = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              const Text('Fecha de la Tarea:', style: TextStyle(fontWeight: FontWeight.bold)),
              ListTile(
                title: Text(_selectedDate == null
                    ? 'Seleccionar Fecha'
                    : 'Fecha seleccionada: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.utc(2020, 1, 1),
                    lastDate: DateTime.utc(2030, 12, 31),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              const Text('Estado de la Tarea:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedEstado,
                decoration: const InputDecoration(labelText: 'Seleccionar Estado'),
                items: _estados.map((estado) {
                  return DropdownMenuItem(
                    value: estado,
                    child: Text(estado),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedEstado = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              const Text('Ubicación en el Mapa:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: FlutterMap(
                  mapController: _mapController, // Asignar el MapController
                  options: MapOptions(
                    center: _selectedLocation ?? const LatLng(-12.0464, -77.0428), // Lima por defecto
                    zoom: 13,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
                      _mapController.move(point, _mapController.zoom); // Centrar el mapa en la nueva ubicación
                    },
                    // --- NUEVO: Callback para cuando el mapa está listo ---
                    onMapReady: () {
                      if (_selectedLocation != null && !_initialMapMoved) {
                        _mapController.move(_selectedLocation!, _mapController.zoom);
                        setState(() {
                          _initialMapMoved = true; // Marca que ya se movió el mapa inicialmente
                        });
                      }
                    },
                    // -----------------------------------------------------
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Actualizar Tarea', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}