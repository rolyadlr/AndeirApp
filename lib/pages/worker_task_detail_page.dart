// lib/pages/worker_task_detail_page.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:intl/intl.dart'; // <--- IMPORTACIÓN NECESARIA

class WorkerTaskDetailPage extends StatefulWidget {
  final DocumentSnapshot taskDocument;

  const WorkerTaskDetailPage({super.key, required this.taskDocument});

  @override
  State<WorkerTaskDetailPage> createState() => _WorkerTaskDetailPageState();
}

class _WorkerTaskDetailPageState extends State<WorkerTaskDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  String? _currentEstado;
  final TextEditingController _observacionesController = TextEditingController();
  List<String> _photoUrls = []; // Para almacenar las URLs de las fotos

  final List<String> _estados = ['pendiente', 'en progreso', 'completada', 'cancelada'];

  // Datos de la tarea
  String? _actividad;
  DateTime? _fecha; // <--- CAMBIO AQUÍ: Ahora es DateTime?
  LatLng? _ubicacion;
  String? _usuarioAsignadoId; // ID del trabajador
  String? _observacionesIniciales; // Si ya existen observaciones
  List<String>? _fotosIniciales; // Si ya existen fotos

  String _adminName = 'Cargando...'; // Para mostrar quién asignó la tarea

  // MapController para el mapa (aunque esté deshabilitada la interacción)
  final MapController _mapController = MapController();
  bool _initialMapMoved = false; // Bandera para mover el mapa solo una vez

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
    _fetchAdminName(); // Este método ahora es más genérico
  }

  void _loadTaskDetails() {
    final data = widget.taskDocument.data() as Map<String, dynamic>;
    _actividad = data['actividad'];

    // --- CAMBIO CLAVE AQUÍ: Leer la fecha como Timestamp y convertirla a DateTime ---
    final Timestamp? timestampFecha = data['fecha'] as Timestamp?;
    _fecha = timestampFecha?.toDate(); // Asignar a DateTime?
    // --------------------------------------------------------------------------------

    _usuarioAsignadoId = data['usuario_asignado']; // Es el ID del trabajador
    _currentEstado = data['ubicacion']?['estado'] ?? 'pendiente';

    if (data['ubicacion'] != null &&
        data['ubicacion']['lat'] != null &&
        data['ubicacion']['lng'] != null) {
      _ubicacion = LatLng(data['ubicacion']['lat'], data['ubicacion']['lng']);
    }

    _observacionesIniciales = data['observaciones_trabajador'];
    if (_observacionesIniciales != null) {
      _observacionesController.text = _observacionesIniciales!;
    }

    _fotosIniciales = List<String>.from(data['fotos_evidencia'] ?? []);
    _photoUrls.addAll(_fotosIniciales!);
  }

  // Si tienes un campo en la tarea que indique el ID del administrador que la creó,
  // puedes usarlo aquí para buscar su nombre.
  Future<void> _fetchAdminName() async {
    // Ejemplo: Si tu tarea tiene un campo 'admin_uid'
    // final adminUid = widget.taskDocument['admin_uid'];
    // if (adminUid != null) {
    //   try {
    //     final adminDoc = await _firestore.collection('usuarios').doc(adminUid).get();
    //     if (adminDoc.exists) {
    //       final adminData = adminDoc.data();
    //       setState(() {
    //         _adminName = '${adminData?['nombres'] ?? ''} ${adminData?['apellidos'] ?? ''}';
    //       });
    //     } else {
    //       setState(() {
    //         _adminName = 'Administrador (ID no encontrado)';
    //       });
    //     }
    //   } catch (e) {
    //     print('Error fetching admin name: $e');
    //     setState(() {
    //       _adminName = 'Administrador (Error)';
    //     });
    //   }
    // } else {
    //   setState(() {
    //     _adminName = 'Administrador'; // Valor por defecto si no hay admin_uid
    //   });
    // }
    // Por ahora, lo mantenemos como un marcador de posición genérico
    setState(() {
      _adminName = 'Administrador';
    });
  }

  Future<void> _takePhoto() async {
    // 1. Obtener el usuario autenticado primero
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay usuario autenticado. Por favor, inicia sesión.')),
      );
      return; // Detiene la función si no hay usuario
    }

    // 2. Ahora, toma la imagen
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    // 3. Procede solo si se seleccionó una imagen
    if (image != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo imagen...')),
      );
      try {
        final ref = _storage.ref().child('task_evidences').child('${widget.taskDocument.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        setState(() {
          _photoUrls.add(url);
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen subida correctamente')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e')),
        );
      }
    }
  }

  Future<void> _updateTaskStatus() async {
    try {
      await _firestore.collection('tareas_asignadas').doc(widget.taskDocument.id).update({
        'ubicacion.estado': _currentEstado,
        'observaciones_trabajador': _observacionesController.text.trim(),
        'fotos_evidencia': _photoUrls,
        'ultima_actualizacion_trabajador': FieldValue.serverTimestamp(), // Marca de tiempo
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado y detalles de la tarea actualizados.')),
      );
      Navigator.pop(context); // Volver a la página anterior después de actualizar
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la tarea: $e')),
      );
    }
  }

  // --- CAMBIO CLAVE AQUÍ: _formatFecha ahora recibe DateTime? ---
  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'Fecha no especificada';
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  Future<void> _launchMapUrl(double lat, double lng) async {
    // La URL de Google Maps para una ubicación específica
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'); // <--- CORRECCIÓN DE URL
    
    if (await url_launcher.canLaunchUrl(url)) {
      await url_launcher.launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_actividad == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Tarea'),
        backgroundColor: const Color(0xFF002F6C),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _actividad!,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF002F6C)),
              ),
              const SizedBox(height: 8),
              Text(
                'Asignado por: $_adminName',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),

              _buildInfoRow(Icons.calendar_today, 'Fecha:', _formatFecha(_fecha)), // <--- CAMBIO AQUÍ
              const SizedBox(height: 10),

              _buildInfoRow(Icons.info_outline, 'Estado Actual:', _currentEstado!),
              const SizedBox(height: 10),

              const Text('Actualizar Estado:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              DropdownButtonFormField<String>(
                value: _currentEstado,
                items: _estados.map((estado) {
                  return DropdownMenuItem(
                    value: estado,
                    child: Text(estado.capitalize()), // Extensión para capitalizar
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _currentEstado = value;
                  });
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              const Text('Observaciones del Trabajador:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextField(
                controller: _observacionesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Añade detalles o comentarios sobre la tarea...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Evidencia Fotográfica:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                    onPressed: _takePhoto,
                    tooltip: 'Tomar foto de evidencia',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _photoUrls.isEmpty
                  ? const Text('No hay fotos de evidencia.', style: TextStyle(color: Colors.grey))
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _photoUrls.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Image.network(
                              _photoUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _photoUrls.removeAt(index);
                                  });
                                },
                                child: Container(
                                  color: Colors.red.withOpacity(0.7),
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
              const SizedBox(height: 16),

              const Text('Ubicación de la Tarea:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _ubicacion == null
                  ? const Text('Ubicación no especificada.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 200,
                          child: FlutterMap(
                            mapController: _mapController, // Asigna el MapController
                            options: MapOptions(
                              center: _ubicacion!,
                              zoom: 15,
                              interactiveFlags: InteractiveFlag.none, // Deshabilita la interacción
                              // --- NUEVO: Callback para cuando el mapa está listo ---
                              onMapReady: () {
                                if (_ubicacion != null && !_initialMapMoved) {
                                  _mapController.move(_ubicacion!, _mapController.zoom);
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
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _ubicacion!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _launchMapUrl(_ubicacion!.latitude, _ubicacion!.longitude),
                            icon: const Icon(Icons.directions, color: Colors.blueAccent),
                            label: const Text('Abrir en Google Maps', style: TextStyle(color: Colors.blueAccent)),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _updateTaskStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Guardar Cambios', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF002F6C), size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// Extensión para capitalizar la primera letra de una cadena
extension WorkerTaskStringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}