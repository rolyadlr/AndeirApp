// lib/pages/Administrador/view_task_report_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewTaskReportPage extends StatelessWidget {
  final DocumentSnapshot taskDocument;

  const ViewTaskReportPage({super.key, required this.taskDocument});

  final Color azulIndigo = const Color(0xFF002F6C);
  final Color rojo = const Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> taskData = taskDocument.data() as Map<String, dynamic>;

    // Obtener los detalles del reporte
    final String actividad = taskData['actividad'] ?? 'Actividad no especificada';
    // CORRECTED: Use 'observaciones_trabajador' instead of 'reporte_descripcion'
    final String reporteDescripcion = taskData['observaciones_trabajador'] ?? 'No se proporcionó descripción del reporte.';
    // CORRECTED: Use 'fotos_evidencia' instead of 'imagenes_reporte'
    final List<String> imagenesReporte = List<String>.from(taskData['fotos_evidencia'] ?? []);
    final String estado = taskData['ubicacion']?['estado'] ?? 'pendiente';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de la Entrega de Tarea', style: TextStyle(color: Colors.white)),
        backgroundColor: azulIndigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tarea: $actividad',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF002F6C)),
            ),
            const SizedBox(height: 10),
            Text(
              'Estado de la Tarea: ${estado.toUpperCase()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: estado == 'completada' ? Colors.green.shade700 : rojo,
              ),
            ),
            const Divider(height: 30, thickness: 1),
            const Text(
              'Reporte del Trabajador:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                reporteDescripcion,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Imágenes Adjuntas:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            if (imagenesReporte.isEmpty)
              const Text(
                'No se adjuntaron imágenes.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black45),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemCount: imagenesReporte.length,
                itemBuilder: (context, index) {
                  final imageUrl = imagenesReporte[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              backgroundColor: Colors.black,
                              iconTheme: const IconThemeData(color: Colors.white),
                            ),
                            backgroundColor: Colors.black,
                            body: Center(
                              child: Image.network(imageUrl),
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
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
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}