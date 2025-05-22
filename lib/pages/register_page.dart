import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nombresController = TextEditingController();
  final TextEditingController apellidosController = TextEditingController();
  final TextEditingController dniController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController celularController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

Future<void> registrarUsuario(BuildContext context) async {
  // Validaciones básicas
  if (nombresController.text.isEmpty ||
      apellidosController.text.isEmpty ||
      dniController.text.isEmpty ||
      correoController.text.isEmpty ||
      celularController.text.isEmpty ||
      passwordController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor, completa todos los campos')),
    );
    return;
  }

  if (passwordController.text.length < 6) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres')),
    );
    return;
  }

  try {
    // Crear cuenta
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: correoController.text.trim(),
      password: passwordController.text.trim(),
    );

    String uid = userCredential.user!.uid;

    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'nombres': nombresController.text.trim(),
      'apellidos': apellidosController.text.trim(),
      'dni': dniController.text.trim(),
      'correo': correoController.text.trim(),
      'celular': celularController.text.trim(),
      'foto_url': '',
      'rol': 'trabajador',
    });

    // Limpiar campos
    nombresController.clear();
    apellidosController.clear();
    dniController.clear();
    correoController.clear();
    celularController.clear();
    passwordController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro exitoso. Inicia sesión.')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  } on FirebaseAuthException catch (e) {
    String mensaje = '';
    if (e.code == 'email-already-in-use') {
      mensaje = 'Este correo ya está en uso.';
    } else if (e.code == 'weak-password') {
      mensaje = 'La contraseña es muy débil.';
    } else {
      mensaje = 'Error: ${e.message}';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error inesperado: $e')),
    );
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
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
                      controller: correoController,
                      decoration: const InputDecoration(labelText: 'Correo electrónico'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: celularController,
                      decoration: const InputDecoration(labelText: 'N° de celular'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => registrarUsuario(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                      ),
                      child: const Text(
                        'Registrarse',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Ya tengo una cuenta'),
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
