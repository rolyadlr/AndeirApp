import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart'; 
import 'calendar_page.dart';
import 'profile_page.dart';
import 'messages_page.dart';


class HomePage extends StatefulWidget {
  final String userName;

  const HomePage({super.key, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
      _pages.addAll([
        _buildHomePage(),
        const CalendarPage(),
        const MessagesPage(),
        const ProfilePage(),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
  currentIndex: _currentIndex,
  selectedItemColor: Colors.white,
  unselectedItemColor: Colors.white70,
  backgroundColor: const Color(0xFF3F51B5),
  type: BottomNavigationBarType.fixed,
  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
  unselectedLabelStyle: const TextStyle(fontSize: 12),
  onTap: (index) {
    setState(() {
      _currentIndex = index;
    });
  },
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Inicio',
    ),
      BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today_outlined),
      activeIcon: Icon(Icons.calendar_today),
      label: 'Calendario',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.mail_outline),
      activeIcon: Icon(Icons.mail),
      label: 'Mensajes',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ],
),

    );
  }

  Widget _buildHomePage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              '¡Bienvenido, ${widget.userName}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3F51B5),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tareas pendientes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildTaskCard(
              isPending: true,
              title: 'Instalación de software',
              subtitle: 'Lunes 9:00 AM',
              icon: Icons.computer,
            ),
            _buildTaskCard(
              isPending: true,
              title: 'Reunión de proyecto',
              subtitle: 'Martes 2:00 PM',
              icon: Icons.people,
            ),
            const SizedBox(height: 20),
            const Text(
              'Avisos recientes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildTaskCard(
              isPending: false,
              title: 'Feriado el viernes',
              subtitle: 'Recuerda que no hay clases',
              icon: Icons.event,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required bool isPending,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: isPending ? Colors.orange : Colors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
