// lib/pages/worker_task_detail_page.dart
import 'dart:io'; // Para el manejo de archivos al tomar fotos
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:intl/intl.dart';

/// WorkerTaskDetailPage muestra los detalles de una tarea asignada a un trabajador
/// y permite al trabajador actualizar su estado, añadir observaciones y subir fotos de evidencia.
class WorkerTaskDetailPage extends StatefulWidget {
  final DocumentSnapshot taskDocument;
  final bool
  isEditable; // Nuevo: indica si la tarea es editable o solo de vista.

  const WorkerTaskDetailPage({
    super.key,
    required this.taskDocument,
    this.isEditable = true, // Por defecto, es editable.
  });

  @override
  State<WorkerTaskDetailPage> createState() => _WorkerTaskDetailPageState();
}

class _WorkerTaskDetailPageState extends State<WorkerTaskDetailPage> {
  // Instancias de Firebase para interactuar con Firestore, Storage y Auth.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  String?
  _currentEstado; // Estado actual de la tarea, editable por el trabajador.
  final TextEditingController _observacionesController =
      TextEditingController();
  List<String> _photoUrls = []; // Lista de URLs de fotos de evidencia.

  // Lista de estados posibles para una tarea.
  static const List<String> _estados = [
    'Pendiente',
    'En progreso',
    'Completada',
    'Cancelada',
  ];

  // Variables para almacenar los datos iniciales de la tarea.
  String? _actividad;
  DateTime? _fecha;
  LatLng? _ubicacion;
  String? _adminId; // ID del administrador que asignó la tarea (si aplica).
  String?
  _observacionesIniciales; // Observaciones del trabajador guardadas previamente.

  // Nombre del administrador, inicialmente 'Cargando...'
  String _adminName = 'Cargando...';

  // Controlador para el mapa.
  final MapController _mapController = MapController();
  bool _initialMapMoved =
      false; // Bandera para asegurar que el mapa solo se mueva una vez.

  @override
  void initState() {
    super.initState();
    _loadTaskDetails(); // Cargar los detalles de la tarea al inicializar el estado.
    _fetchAdminName(); // Obtener el nombre del administrador.
  }

  @override
  void dispose() {
    _observacionesController.dispose(); // Liberar el controlador de texto.
    super.dispose();
  }

  /// Carga los detalles de la tarea desde el `taskDocument` recibido.
  void _loadTaskDetails() {
    final data =
        widget.taskDocument.data()
            as Map<String, dynamic>?; // Acceso seguro a los datos.

    if (data == null) {
      // Manejar el caso donde no hay datos en el documento.
      _actividad = 'Tarea no encontrada';
      _currentEstado = 'desconocido';
      return;
    }

    _actividad = data['actividad'];

    final Timestamp? timestampFecha = data['fecha'] as Timestamp?;
    _fecha = timestampFecha?.toDate();

    _adminId =
        data['admin_asignador_id']; // Asumiendo que hay un campo para el ID del admin.
    final rawEstado = (data['ubicacion']?['estado'] ?? 'pendiente') as String;
    _currentEstado = _estados.firstWhere(
      (e) => e.toLowerCase() == rawEstado.toLowerCase(),
      orElse: () => _estados[0],
    );
    if (data['ubicacion'] != null &&
        data['ubicacion']['lat'] != null &&
        data['ubicacion']['lng'] != null) {
      _ubicacion = LatLng(data['ubicacion']['lat'], data['ubicacion']['lng']);
    }

    _observacionesIniciales = data['observaciones_trabajador'];
    if (_observacionesIniciales != null) {
      _observacionesController.text = _observacionesIniciales!;
    }

    // Asegurarse de que _fotosIniciales sea List<String>
    final dynamic fotosData = data['fotos_evidencia'];
    if (fotosData is List) {
      _photoUrls.addAll(List<String>.from(fotosData.whereType<String>()));
    }
  }

  /// Obtiene el nombre del administrador que asignó la tarea.
  /// Asume que hay una colección 'usuarios' con los detalles del administrador.
  Future<void> _fetchAdminName() async {
    if (_adminId != null) {
      try {
        final adminDoc =
            await _firestore.collection('usuarios').doc(_adminId).get();
        if (adminDoc.exists) {
          final data = adminDoc.data();
          setState(() {
            _adminName =
                '${data?['nombres'] ?? ''} ${data?['apellidos'] ?? ''}';
          });
        } else {
          setState(() {
            _adminName = 'Administrador desconocido';
          });
          print(
            'Advertencia: Documento del administrador con ID $_adminId no encontrado.',
          );
        }
      } catch (e) {
        setState(() {
          _adminName = 'Error al cargar admin';
        });
        print('Error al obtener nombre del administrador: $e');
      }
    } else {
      setState(() {
        _adminName = 'No asignado por admin';
      });
    }
  }

  /// Permite al usuario tomar una foto y la sube a Firebase Storage.
  Future<void> _takePhoto() async {
    if (!widget.isEditable) return; // No permitir tomar fotos si no es editable

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: No hay usuario autenticado. Por favor, inicia sesión.',
            ),
          ),
        );
      }
      return;
    }

    final XFile? image = await _picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Subiendo imagen...')));
      }
      try {
        final ref = _storage
            .ref()
            .child('task_evidences')
            .child(widget.taskDocument.id)
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        setState(() {
          _photoUrls.add(url);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Imagen subida correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
        }
        print('Error al subir imagen: $e'); // Para depuración
      }
    }
  }

  /// Actualiza el estado de la tarea, observaciones y URLs de fotos en Firestore.
  Future<void> _updateTaskStatus() async {
    if (!widget.isEditable) return; // No permitir guardar si no es editable

    try {
      await _firestore
          .collection('tareas_asignadas')
          .doc(widget.taskDocument.id)
          .update({
            'ubicacion.estado': _currentEstado,
            'observaciones_trabajador': _observacionesController.text.trim(),
            'fotos_evidencia': _photoUrls,
            'ultima_actualizacion_trabajador': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado y detalles de la tarea actualizados.'),
          ),
        );
        Navigator.pop(
          context,
        ); // Regresar a la página anterior después de actualizar.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar la tarea: $e')),
        );
      }
      print('Error al actualizar la tarea: $e'); // Para depuración
    }
  }

  /// Formatea un objeto DateTime a String en formato 'dd/MM/yyyy'.
  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'Fecha no especificada';
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  /// Abre la ubicación de la tarea en Google Maps.
  Future<void> _launchMapUrl(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await url_launcher.canLaunchUrl(url)) {
      await url_launcher.launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir el mapa. Asegúrate de tener Google Maps instalado.',
            ),
          ),
        );
      }
      print('Error: No se pudo lanzar la URL del mapa: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un indicador de carga si los detalles de la actividad aún no se han cargado.
    if (_actividad == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditable ? 'Editar Tarea' : 'Detalles de la Tarea',
        ),
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002F6C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Asignado por: $_adminName',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),

              _buildInfoRow(
                Icons.calendar_today,
                'Fecha:',
                _formatFecha(_fecha),
              ),
              const SizedBox(height: 10),

              // Se capitaliza la primera letra del estado para una mejor presentación.
              _buildInfoRow(
                Icons.info_outline,
                'Estado Actual:',
                _currentEstado!.capitalize(),
              ),
              const SizedBox(height: 10),

              if (widget.isEditable) ...[
                const Text(
                  'Actualizar Estado:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                DropdownButtonFormField<String>(
                  value: _currentEstado,
                  items:
                      _estados.map((estado) {
                        return DropdownMenuItem(
                          value: estado,
                          child: Text(
                            estado.capitalize(),
                          ), // Capitalizar para mostrar
                        );
                      }).toList(),
                  onChanged:
                      widget.isEditable
                          ? (value) {
                            setState(() {
                              _currentEstado = value;
                            });
                          }
                          : null, // Deshabilita el Dropdown si no es editable
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Observaciones del Trabajador:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextField(
                  controller: _observacionesController,
                  maxLines: 4,
                  enabled:
                      widget
                          .isEditable, // Deshabilita el TextField si no es editable
                  decoration: const InputDecoration(
                    hintText: 'Añade detalles o comentarios sobre la tarea...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint:
                        true, // Alinea el hint text en la parte superior.
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Evidencia Fotográfica:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.blueAccent,
                      ),
                      onPressed:
                          widget.isEditable
                              ? _takePhoto
                              : null, // Deshabilita el botón si no es editable
                      tooltip:
                          widget.isEditable
                              ? 'Tomar foto de evidencia'
                              : 'No se pueden añadir fotos',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              _photoUrls.isEmpty
                  ? const Text(
                    'No hay fotos de evidencia.',
                    style: TextStyle(color: Colors.grey),
                  )
                  : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: _photoUrls.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              _photoUrls[index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder:
                                  (context, error, stackTrace) => const Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.red,
                                  ),
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (widget
                              .isEditable) // Solo permite eliminar si es editable
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _photoUrls.removeAt(
                                      index,
                                    ); // Permite eliminar fotos de la lista.
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              const SizedBox(height: 16),

              const Text(
                'Ubicación de la Tarea:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _ubicacion == null
                  ? const Text('Ubicación no especificada.')
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 200,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            center: _ubicacion!,
                            zoom: 15,
                            interactiveFlags:
                                InteractiveFlag
                                    .none, // Deshabilita la interacción para ver el mapa estático.
                            onMapReady: () {
                              if (_ubicacion != null && !_initialMapMoved) {
                                _mapController.move(
                                  _ubicacion!,
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
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _ubicacion!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.blue,
                                    size: 40,
                                  ),
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
                          onPressed:
                              () => _launchMapUrl(
                                _ubicacion!.latitude,
                                _ubicacion!.longitude,
                              ),
                          icon: const Icon(
                            Icons.directions,
                            color: Colors.blueAccent,
                          ),
                          label: const Text(
                            'Abrir en Google Maps',
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 24),

              if (widget
                  .isEditable) // Solo muestra el botón de guardar si es editable
                ElevatedButton(
                  onPressed: _updateTaskStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text(
                    'Guardar Cambios',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget auxiliar para mostrar una fila de información con un icono y una etiqueta.
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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

extension WorkerTaskStringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
