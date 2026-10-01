import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';
import 'profile_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final name = (controller.sessionName ?? '').trim();
    final email = controller.hideEmail
        ? 'Correo oculto'
        : (controller.sessionEmail ?? '');
    final phone = (controller.sessionPhone ?? '').trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(color: Color(0x1A172033), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: ProfileAvatar(
              name: name,
              photo: controller.sessionPhoto,
              radius: 72,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name.isEmpty ? 'Tu cuenta' : name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink, height: 1.1),
        ),
        const SizedBox(height: 8),
        _ContactLine(icon: Icons.mail_outline_rounded, text: email.isEmpty ? 'Sin correo' : email),
        const SizedBox(height: 4),
        _ContactLine(
          icon: Icons.phone_outlined,
          text: phone.isEmpty ? 'Sin teléfono' : phone,
        ),
        if (controller.usesCloud) ...[
          const SizedBox(height: 4),
          const _ContactLine(icon: Icons.cloud_outlined, text: 'Listas y viaje en el servidor'),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: blue,
              side: const BorderSide(color: blue),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'CONFIGURACIÓN',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _SettingTile(
                icon: Icons.lock_outline_rounded,
                title: 'Privacidad',
                subtitle: controller.hideEmail ? 'Correo oculto' : 'Correo visible',
                onTap: () => _open(context, const PrivacySettingsScreen()),
              ),
              const Divider(height: 1, indent: 64),
              _SettingTile(
                icon: Icons.language_rounded,
                title: 'Idioma',
                subtitle: 'Español',
                onTap: () => _open(context, const LanguageSettingsScreen()),
              ),
              const Divider(height: 1, indent: 64),
              _SettingTile(
                icon: Icons.shield_outlined,
                title: 'Seguridad',
                subtitle: 'Contraseña',
                onTap: () => _open(context, const SecuritySettingsScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'AYUDA Y NOTIFICACIONES',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _SettingTile(
                icon: Icons.help_outline_rounded,
                title: 'Ayuda',
                subtitle: 'Cómo usar la app',
                onTap: () => _open(context, const HelpSettingsScreen()),
              ),
              const Divider(height: 1, indent: 64),
              _SettingTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                subtitle: controller.notificationsEnabled ? 'Activadas' : 'Desactivadas',
                onTap: () => _open(context, const NotificationsSettingsScreen()),
              ),
              const Divider(height: 1, indent: 64),
              _SettingTile(
                icon: Icons.logout_rounded,
                title: 'Cerrar sesión',
                subtitle: 'Salir de tu cuenta',
                iconColor: warn,
                titleColor: warn,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('Vas a salir de tu cuenta en este dispositivo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
          ],
        );
      },
    );
    if (leave == true && context.mounted) {
      await context.read<AppController>().signOut();
    }
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF667085)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 15),
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = blue,
    this.titleColor = ink,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE7F0FF),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
    );
  }
}
