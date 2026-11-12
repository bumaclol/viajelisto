import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/save_status.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
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
        const Text(
          'Mi cuenta',
          style: TextStyle(
            fontFamily: displayFamily,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: forestDeep,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 18),
        if (!controller.signedIn) ...[
          const Text(
            'Puedes preparar el viaje sin cuenta. Lo que anotes se guarda solo en este navegador.',
            style: TextStyle(color: moss, height: 1.35),
          ),
          const SizedBox(height: 12),
          const SaveStatus(),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: forest,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 18),
        ],
        if (controller.signedIn) ...[
        const Text(
          'SESIÓN INICIADA',
          style: TextStyle(
            color: moss,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ProfileAvatar(name: name, photo: controller.sessionPhoto, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Tu cuenta' : name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: forestDeep),
                  ),
                  Text(
                    email.isEmpty ? 'Sin correo' : email,
                    style: const TextStyle(color: moss),
                  ),
                  Text(
                    phone.isEmpty ? 'Sin teléfono' : phone,
                    style: const TextStyle(color: moss),
                  ),
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: forest,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            ),
            child: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SaveStatus(),
        const SizedBox(height: 18),
        if (controller.cloudSave == CloudSave.saved)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lime,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_done_outlined, color: forestDeep),
                    SizedBox(width: 8),
                    Text(
                      'Todo al salvo',
                      style: TextStyle(fontWeight: FontWeight.w800, color: forestDeep, fontSize: 18),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Tus listas y tu viaje están en tu cuenta. Inicia sesión en otro dispositivo y sigue donde quedaste.',
                  style: TextStyle(color: forestDeep, height: 1.3),
                ),
              ],
            ),
          ),
        if (controller.cloudSave == CloudSave.saved) const SizedBox(height: 18),
        ],
        const Text(
          'Dónde está guardado',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: forestDeep),
        ),
        const SizedBox(height: 8),
        _StorageRow(
          icon: Icons.language_rounded,
          title: 'En este navegador',
          subtitle:
              '${_pieces(controller.lists.length, 'lista', 'listas')} y ${_pieces(controller.trips.length, 'viaje', 'viajes')} guardados',
        ),
        if (controller.cloudSave == CloudSave.saved)
          const _StorageRow(
            icon: Icons.cloud_outlined,
            title: 'En tu cuenta',
            subtitle: 'El último guardado remoto se completó',
          ),
        if (controller.cloudSave == CloudSave.failed)
          _StorageRow(
            icon: Icons.cloud_off_outlined,
            title: 'No se guardó en la cuenta',
            subtitle: controller.cloudSaveDetail ?? 'Revisa la conexión e inténtalo de nuevo.',
          ),
        if (controller.cloudSave == CloudSave.saving)
          const _StorageRow(
            icon: Icons.cloud_upload_outlined,
            title: 'Guardando',
            subtitle: 'Todavía no está en la cuenta',
          ),
        const SizedBox(height: 22),
        const Text(
          'Por ahora, nos vemos en la web',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: forestDeep),
        ),
        const SizedBox(height: 4),
        const Text(
          'Usa TravelEquality desde tu navegador. La versión para instalar en el teléfono todavía no está disponible.',
          style: TextStyle(color: moss, height: 1.35),
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
              if (controller.signedIn) ...[
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

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Icon(icon, color: forest, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: forestDeep)),
                Text(subtitle, style: const TextStyle(color: moss, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.check_rounded, color: forest, size: 18),
        ],
      ),
    );
  }
}

String _pieces(int count, String one, String many) => '$count ${count == 1 ? one : many}';

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = forest,
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
        backgroundColor: const Color(0xFFE7F3D8),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF98A2B3)),
    );
  }
}
