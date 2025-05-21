import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nombresController = TextEditingController();
  final TextEditingController apellidosController = TextEditingController();
  final TextEditingController dniController = TextEditingController();
  final TextEditingController celularController = TextEditingController();
  final TextEditingController correoController = TextEditingController();

  String? imageUrl;
  File? _imageFile;

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
        dniController.text = data['dni'] ?? '';
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
      'dni': dniController.text.trim(),
      'celular': celularController.text.trim(),
      'correo': correoController.text.trim(),
      'fotoPerfil': nuevaUrl,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil actualizado')),
    );
  }

  void cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
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
    final avatar = _imageFile != null
        ? FileImage(_imageFile!)
        : (imageUrl != null ? NetworkImage(imageUrl!) : const AssetImage('assets/default_avatar.png'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
            const Text('Toca la imagen para cambiarla'),

            const SizedBox(height: 30),
            TextField(
              controller: nombresController,
              decoration: const InputDecoration(labelText: 'Nombres'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: apellidosController,
              decoration: const InputDecoration(labelText: 'Apellidos'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dniController,
              decoration: const InputDecoration(labelText: 'DNI'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: celularController,
              decoration: const InputDecoration(labelText: 'Celular'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: correoController,
              decoration: const InputDecoration(labelText: 'Correo'),
              readOnly: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
          onPressed: guardarCambios,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          child: const Text(
            'Guardar Cambios',
            style: TextStyle(color: Colors.white),
          ),
        ),
          ],
        ),
      ),
    );
  }
}
