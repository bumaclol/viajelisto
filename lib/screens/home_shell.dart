import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'calculator_screen.dart';
import 'home_screen.dart';
import 'packing_screen.dart';
import 'profile_screen.dart';
import 'profile_settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  var _askingMerge = false;

  static const _subtitles = [
    'Tu próximo buen recuento.',
    'Menos olvidos, más viaje.',
    'Las cuentas, claras.',
    'Tus planes van contigo.',
  ];

  void _open(int index) => setState(() => _index = index);

  Future<void> _askMerge() async {
    final controller = context.read<AppController>();
    if (controller.pendingMerge == null) {
      _askingMerge = false;
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hay dos versiones del viaje'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Este navegador y tu cuenta no tienen lo mismo. Elige qué hacer. No se reemplaza nada hasta que lo decidas.',
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, 'local'),
                child: const Text('Conservar este navegador'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, 'remote'),
                child: const Text('Usar la cuenta'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 'merge'),
                child: const Text('Combinar'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'local':
        await controller.keepBrowserData();
      case 'remote':
        await controller.useAccountData();
      case 'merge':
        await controller.combineAccount();
    }
    _askingMerge = false;
  }

  Widget get _page {
    switch (_index) {
      case 1:
        return const PackingScreen();
      case 2:
        return const CalculatorScreen();
      case 3:
        return const ProfileScreen();
      default:
        return HomeScreen(onPrepare: () => _open(1), onExpenses: () => _open(2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = context.watch<AppController>().pendingMerge;
    if (pending != null && !_askingMerge) {
      _askingMerge = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askMerge();
      });
    }
    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _BrandBar(
                  subtitle: _subtitles[_index],
                  onBell: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const NotificationsSettingsScreen()),
                    );
                  },
                ),
                Expanded(child: _page),
                _BottomNav(index: _index, onSelect: _open),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar({required this.subtitle, required this.onBell});

  final String subtitle;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TravelEquality',
                  style: TextStyle(
                    fontFamily: displayFamily,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: forestDeep,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: moss, fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notificaciones',
            onPressed: onBell,
            icon: const Icon(Icons.notifications_none_rounded, color: forestDeep),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.luggage_outlined, Icons.luggage_rounded, 'Equipaje'),
    (Icons.directions_car_filled_outlined, Icons.directions_car_filled_rounded, 'Viaje'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Cuenta'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: index == i ? _items[i].$2 : _items[i].$1,
                    label: _items[i].$3,
                    selected: index == i,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Viaje en grupo. Vuelve con buenos recuerdos.',
            style: TextStyle(color: moss, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? forestDeep : moss;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? lime : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
