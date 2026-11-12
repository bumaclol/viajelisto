import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class SaveStatus extends StatelessWidget {
  const SaveStatus({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final (icon, text) = switch (controller.cloudSave) {
      CloudSave.saving => (Icons.cloud_upload_outlined, compact ? 'Guardando' : 'Guardando en tu cuenta...'),
      CloudSave.saved => (Icons.cloud_done_outlined, compact ? 'En tu cuenta' : 'Guardado en tu cuenta'),
      CloudSave.failed => (
          Icons.cloud_off_outlined,
          compact
              ? 'No se guardó'
              : controller.cloudSaveDetail ?? 'No se pudo guardar en la cuenta. Sigue en este navegador.',
        ),
      CloudSave.browser => (Icons.cloud_outlined, compact ? 'Guardado' : 'Guardado en este navegador'),
    };
    final label = Text(text, style: const TextStyle(color: moss, fontSize: 13, height: 1.3));
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(icon, size: 16, color: moss),
        const SizedBox(width: 6),
        if (compact) label else Expanded(child: label),
      ],
    );
  }
}
