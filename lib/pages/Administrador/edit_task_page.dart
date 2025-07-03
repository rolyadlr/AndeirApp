import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class EditTaskPage extends StatefulWidget {
  final DocumentSnapshot taskDocument;

  const EditTaskPage({super.key, required this.taskDocument});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedTrabajadorId;
  String? _selectedActividad;
  LatLng? _selectedLocation;
  DateTime? _selectedDate;
  String? _selectedEstado;

  List<DocumentSnapshot> _trabajadores = [];
  List<String> _actividades = [];
  List<String> _estados = [
    'pendiente',
    'en progreso',
    'completada',
    'cancelada',
  ];

  final MapController _mapController = MapController();
  bool _initialMapMoved = false;

  final azulIntenso = const Color(0xFF002E6D);
  final rojoOscuro = const Color(0xFFB71C1C);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchDropdownData();
  }

  void _loadInitialData() {
    final data = widget.taskDocument.data() as Map<String, dynamic>;

    _selectedTrabajadorId = data['usuario_asignado'];
    _selectedActividad = data['actividad'];
    if (data['ubicacion'] != null &&
        data['ubicacion']['lat'] != null &&
        data['ubicacion']['lng'] != null) {
      _selectedLocation = LatLng(
        data['ubicacion']['lat'],
        data['ubicacion']['lng'],
      );
    }

    if (data['fecha'] is Timestamp) {
      _selectedDate = (data['fecha'] as Timestamp).toDate();
    } else if (data['fecha'] is String) {
      _selectedDate = DateTime.tryParse(data['fecha']);
    }

    _selectedEstado = data['ubicacion']?['estado'] ?? 'pendiente';
  }

  void _fetchDropdownData() async {
    final trabajadoresSnapshot = await _firestore.collection('usuarios').get();
    final actividadesSnapshot =
        await _firestore.collection('actividades').get();

    setState(() {
      _trabajadores = trabajadoresSnapshot.docs;
      _actividades =
          actividadesSnapshot.docs
              .map((doc) => doc['nombre'].toString())
              .toList();
    });
  }

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
      await _firestore
          .collection('tareas_asignadas')
          .doc(widget.taskDocument.id)
          .update({
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

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text(
              '¿Estás seguro de que quieres eliminar esta tarea?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: rojoOscuro),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('tareas_asignadas')
            .doc(widget.taskDocument.id)
            .delete();
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: azulIntenso,
        title: const Text(
          'Editar Tarea',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: rojoOscuro),
            onPressed: _deleteTask,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trabajador Asignado:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedTrabajadorId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Seleccionar Trabajador',
                ),
                items:
                    _trabajadores.map((trabajador) {
                      final data = trabajador.data() as Map<String, dynamic>;
                      final name =
                          '${data['nombres'] ?? ''} ${data['apellidos'] ?? ''}'
                              .trim();
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

              const Text(
                'Actividad:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedActividad,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Seleccionar Actividad',
                ),
                items:
                    _actividades.map((actividad) {
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
                    _selectedActividad = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Fecha de la Tarea:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: azulIntenso),
                ),
                title: Text(
                  _selectedDate == null
                      ? 'Seleccionar Fecha'
                      : 'Fecha: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                ),
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

              const Text(
                'Estado de la Tarea:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedEstado,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Seleccionar Estado',
                ),
                items:
                    _estados.map((estado) {
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

              const Text(
                'Ubicación en el Mapa:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 250,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center:
                        _selectedLocation ?? const LatLng(-12.0464, -77.0428),
                    zoom: 13,
                    onTap: (tapPosition, point) {
                      setState(() {
                        _selectedLocation = point;
                      });
                      _mapController.move(point, _mapController.zoom);
                    },
                    onMapReady: () {
                      if (_selectedLocation != null && !_initialMapMoved) {
                        _mapController.move(
                          _selectedLocation!,
                          _mapController.zoom,
                        );
                        setState(() {
                          _initialMapMoved = true;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _updateTask,
                icon: const Icon(Icons.save),
                label: const Text('Actualizar Tarea'),
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
          ),
        ),
      ),
    );
  }
}
