import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class SaveStatus extends StatelessWidget {
  const SaveStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final (icon, text) = switch (controller.cloudSave) {
      CloudSave.saving => (Icons.cloud_upload_outlined, 'Guardando en tu cuenta...'),
      CloudSave.saved => (Icons.cloud_done_outlined, 'Guardado en tu cuenta'),
      CloudSave.failed => (
          Icons.cloud_off_outlined,
          controller.cloudSaveDetail ?? 'No se pudo guardar en la cuenta. Sigue en este navegador.',
        ),
      CloudSave.browser => (Icons.devices_outlined, 'Guardado en este navegador'),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: moss),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: const TextStyle(color: moss, fontSize: 13, height: 1.3)),
        ),
      ],
    );
  }
}
