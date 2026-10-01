import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _ready = false;
  bool _busy = false;
  String? _message;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final controller = context.read<AppController>();
    _name.text = controller.sessionName ?? '';
    _phone.text = controller.sessionPhone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: blue),
                title: const Text('Elegir de la galería'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: blue),
                  title: const Text('Tomar una foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (file == null || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final error = await context.read<AppController>().setProfilePhoto(bytes);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error ?? 'Foto guardada.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'No se pudo abrir la foto.';
      });
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _busy = true);
    await context.read<AppController>().removeProfilePhoto();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = 'Foto quitada.';
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final error = await context.read<AppController>().updateProfile(
          name: _name.text,
          phone: _phone.text,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _message = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final hasPhoto = decodeProfilePhoto(controller.sessionPhoto) != null;

    return Scaffold(
      backgroundColor: pageBottom,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: pageTop,
        foregroundColor: ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: ProfileAvatar(
              name: _name.text,
              photo: controller.sessionPhoto,
              radius: 64,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _busy ? null : _choosePhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(hasPhoto ? 'Cambiar foto' : 'Agregar foto'),
            ),
          ),
          if (hasPhoto)
            Center(
              child: TextButton(
                onPressed: _busy ? null : _removePhoto,
                child: const Text('Quitar foto'),
              ),
            ),
          const SizedBox(height: 8),
          const Text('La foto es opcional. Si la pones, se ve tu rostro en el perfil.'),
          const SizedBox(height: 16),
          const Text('Nombre', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ana Gómez'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Text('Teléfono', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '+56 9 1234 5678'),
          ),
          const SizedBox(height: 16),
          const Text('Correo', style: TextStyle(fontWeight: FontWeight.w700, color: ink)),
          const SizedBox(height: 8),
          Text(
            controller.sessionEmail ?? '',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 16),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Guardar cambios'),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _message == 'Foto guardada.' || _message == 'Foto quitada.' ? good : warn,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
