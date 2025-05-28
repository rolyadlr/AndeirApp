import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../login_page.dart';

class AdminMiCuentaPage extends StatefulWidget {
  const AdminMiCuentaPage({super.key});

  @override
  State<AdminMiCuentaPage> createState() => _AdminMiCuentaPageState();
}

class _AdminMiCuentaPageState extends State<AdminMiCuentaPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nombresController = TextEditingController();
  final TextEditingController apellidosController = TextEditingController();
  final TextEditingController celularController = TextEditingController();
  final TextEditingController correoController = TextEditingController();

  String? imageUrl;
  File? _imageFile;

  final Color azulIndigo = const Color(0xFF002F6C);
  final Color rojo = const Color(0xFFE53935);
  final Color negro = Colors.black87;

  @override
  void initState() {
    super.initState();
    cargarDatosUsuario();
  }

  Future<void> cargarDatosUsuario() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      final data = doc.data();
      if (data != null) {
        nombresController.text = data['nombres'] ?? '';
        apellidosController.text = data['apellidos'] ?? '';
        celularController.text = data['celular'] ?? '';
        correoController.text = data['correo'] ?? '';
        imageUrl = data['fotoPerfil'];
        setState(() {});
      }
    }
  }

  Future<void> seleccionarImagen() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<String?> subirImagen(File imagen) async {
    final uid = _auth.currentUser!.uid;
    final ref = FirebaseStorage.instance.ref().child('fotos_perfil/$uid.jpg');
    await ref.putFile(imagen);
    return await ref.getDownloadURL();
  }

  Future<void> guardarCambios() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    String? nuevaUrl = imageUrl;

    if (_imageFile != null) {
      nuevaUrl = await subirImagen(_imageFile!);
    }

    await _firestore.collection('usuarios').doc(uid).update({
      'nombres': nombresController.text.trim(),
      'apellidos': apellidosController.text.trim(),
      'celular': celularController.text.trim(),
      'correo': correoController.text.trim(),
      'fotoPerfil': nuevaUrl,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
  }

  void cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cerrar sesión'),
            content: const Text('¿Deseas cerrar sesión?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
    );

    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar =
        _imageFile != null
            ? FileImage(_imageFile!)
            : (imageUrl != null
                ? NetworkImage(imageUrl!)
                : const AssetImage('assets/default_avatar.png'));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: azulIndigo,
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: cerrarSesion,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: seleccionarImagen,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: avatar as ImageProvider,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Toca la imagen para cambiarla',
              style: TextStyle(color: negro),
            ),
            const SizedBox(height: 30),
            buildInputField(Icons.person, 'Nombres', nombresController),
            const SizedBox(height: 10),
            buildInputField(
              Icons.person_outline,
              'Apellidos',
              apellidosController,
            ),
            const SizedBox(height: 10),
            buildInputField(Icons.phone, 'Celular', celularController),
            const SizedBox(height: 10),
            buildInputField(
              Icons.email,
              'Correo',
              correoController,
              readOnly: true,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: guardarCambios,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rojo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInputField(
    IconData icon,
    String label,
    TextEditingController controller, {
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: azulIndigo),
        labelText: label,
        labelStyle: TextStyle(color: negro),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: azulIndigo),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: rojo, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
