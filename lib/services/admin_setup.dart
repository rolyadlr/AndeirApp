import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


Future<void> crearAdminInicial() async {
  try {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final signInMethods = await auth.fetchSignInMethodsForEmail('admin1@gmail.com');
    if (signInMethods.isEmpty) {
      UserCredential adminCredential = await auth.createUserWithEmailAndPassword(
        email: 'admin1@gmail.com',
        password: 'adminandeir1',
      );

      await firestore.collection('usuarios').doc(adminCredential.user!.uid).set({
        'nombres': 'Admin',
        'apellidos': 'Principal',
        'dni': '00000000',
        'correo': 'admin1@gmail.com',
        'celular': '000000000',
        'foto_url': '',
        'rol': 'administrador',
      });

      print('Administrador creado con éxito');
    } else {
      print('El administrador ya existe');
    }
  } catch (e) {
    print('Error al crear el administrador: $e');
  }
}
