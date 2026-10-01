import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class HelpSettingsScreen extends StatelessWidget {
  const HelpSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsPage(
      title: 'Ayuda',
      child: Column(
        children: [
          _HelpCard(
            icon: Icons.luggage_rounded,
            title: 'Equipaje',
            body: 'Elige Playa, Camping o Bosque, marca lo que ya empacaste y crea listas nuevas.',
          ),
          SizedBox(height: 12),
          _HelpCard(
            icon: Icons.directions_car_filled_rounded,
            title: 'Viaje',
            body: 'Ingresa la distancia, el rendimiento, el precio del combustible y los peajes. El gasto se reparte entre los pasajeros.',
          ),
          SizedBox(height: 12),
          _HelpCard(
            icon: Icons.person_rounded,
            title: 'Perfil',
            body: 'La foto es opcional. En Editar perfil cambias el nombre, el teléfono y la foto.',
          ),
          SizedBox(height: 12),
          _HelpCard(
            icon: Icons.notifications_none_rounded,
            title: 'Notificaciones',
            body: 'Puedes activar o desactivar los avisos de esta app en Notificaciones.',
          ),
        ],
      ),
    );
  }
}

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<AppController>().notificationsEnabled;
    return _SettingsPage(
      title: 'Notificaciones',
      child: _SwitchCard(
        title: 'Avisos de la app',
        subtitle: 'Recibe avisos sobre tus listas y el gasto del viaje en este dispositivo.',
        value: enabled,
        onChanged: (value) => context.read<AppController>().setNotificationsEnabled(value),
      ),
    );
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hideEmail = context.watch<AppController>().hideEmail;
    return _SettingsPage(
      title: 'Privacidad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tu cuenta, tus listas y los gastos del viaje se guardan en este dispositivo.',
            style: TextStyle(color: Color(0xFF667085), height: 1.4),
          ),
          const SizedBox(height: 16),
          _SwitchCard(
            title: 'Ocultar correo',
            subtitle: 'El perfil muestra “Correo oculto” en lugar de tu dirección.',
            value: hideEmail,
            onChanged: (value) => context.read<AppController>().setHideEmail(value),
          ),
        ],
      ),
    );
  }
}

class LanguageSettingsScreen extends StatelessWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsPage(
      title: 'Idioma',
      child: _ChoiceCard(
        title: 'Español',
        subtitle: 'La aplicación está en español.',
      ),
    );
  }
}

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _saved = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
      _saved = false;
    });
    final error = await context.read<AppController>().changePassword(
          current: _current.text,
          next: _next.text,
          confirm: _confirm.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = error == null;
      _message = error ?? 'Contraseña actualizada.';
    });
    if (error == null) {
      _current.clear();
      _next.clear();
      _confirm.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'Seguridad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cambia la contraseña de tu cuenta.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Contraseña actual'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Nueva contraseña'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Confirmar contraseña'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Guardar contraseña'),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(color: _saved ? good : warn, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFE7F0FF),
            child: Icon(icon, color: blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: Color(0xFF667085), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBottom,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: pageTop,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [child],
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF667085))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
