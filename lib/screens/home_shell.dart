import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import 'calculator_screen.dart';
import 'packing_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openProfile() => setState(() => _index = 2);

  Widget get _page {
    if (_index == 1) return const CalculatorScreen();
    if (_index == 2) return const ProfileScreen();
    return const PackingScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(onProfile: _openProfile),
              Expanded(child: _page),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE7F0FF),
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined, color: Color(0xFF98A2B3)),
            selectedIcon: Icon(Icons.luggage_rounded, color: blue),
            label: 'Equipaje',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_filled_outlined, color: Color(0xFFE25B5B)),
            selectedIcon: Icon(Icons.directions_car_filled_rounded, color: blue),
            label: 'Viaje',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: Color(0xFF98A2B3)),
            selectedIcon: Icon(Icons.person_rounded, color: blue),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final name = controller.sessionName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.flight_rounded, color: blue, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TravelEquality',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: ink, height: 1.1),
                ),
                Text(
                  name == null || name.isEmpty
                      ? 'Organiza tu próxima aventura'
                      : 'Hola, $name',
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Mi perfil',
            onPressed: onProfile,
            icon: ProfileAvatar(
              name: name,
              photo: controller.sessionPhoto,
              radius: 16,
            ),
          ),
        ],
      ),
    );
  }
}
