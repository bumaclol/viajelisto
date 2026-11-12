import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/packing_list.dart';
import '../state/app_controller.dart';
import '../widgets/save_status.dart';
import '../theme/app_theme.dart';
import '../widgets/name_dialog.dart';

class PackingScreen extends StatefulWidget {
  const PackingScreen({super.key});

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  String? _selectedId;
  final _itemController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final lists = controller.lists;
    final selected = _current(lists);
    final total = selected?.items.length ?? 0;
    final packed = selected?.packedCount ?? 0;
    final percent = total == 0 ? 0 : ((packed / total) * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      children: [
        const Text(
          'Mi equipaje',
          style: TextStyle(
            fontFamily: displayFamily,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: forestDeep,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'PARTE CON UNA LISTA',
          style: TextStyle(
            color: moss,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final list in lists)
              _Chip(
                label: list.name,
                selected: selected?.id == list.id,
                onTap: () => setState(() => _selectedId = list.id),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_tripLabel(controller)} · Mi lista',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: forestDeep),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(color: moss, fontWeight: FontWeight.w700),
              ),
              IconButton(
                tooltip: 'Cambiar nombre',
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final name = await askForName(
                    context,
                    title: 'Cambiar nombre',
                    initial: selected.name,
                  );
                  if (name == null || !context.mounted) return;
                  await context.read<AppController>().renameList(selected.id, name);
                },
                icon: const Icon(Icons.edit_outlined, size: 18, color: moss),
              ),
            ],
          ),
          Text(
            '$packed de $total empacados',
            style: const TextStyle(color: moss),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : packed / total,
              minHeight: 6,
              backgroundColor: line,
              color: forest,
            ),
          ),
          const SizedBox(height: 8),
          if (selected.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Esta lista está vacía. Agrega el primer elemento.',
                style: TextStyle(color: moss, height: 1.3),
              ),
            ),
          for (final item in selected.items)
            _ItemRow(
              name: item.name,
              packed: item.packed,
              quantity: item.quantity,
              onPacked: (value) {
                context.read<AppController>().toggleItem(selected.id, item.id, value);
              },
              onQuantity: (value) {
                context.read<AppController>().setItemQuantity(selected.id, item.id, value);
              },
              onRename: () async {
                final name = await askForName(
                  context,
                  title: 'Editar elemento',
                  initial: item.name,
                );
                if (name == null || !context.mounted) return;
                await context.read<AppController>().renameItem(selected.id, item.id, name);
              },
              onDelete: () => _confirmDelete(selected.id, item.id, item.name),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _itemController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Agregar ítem',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.add, color: forest),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: forest),
              ),
            ),
            onSubmitted: (_) => _addItem(selected.id),
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _createList,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Crear tu propia lista'),
          style: TextButton.styleFrom(foregroundColor: forestDeep),
        ),
        Center(
          child: TextButton(
            onPressed: _confirmRestore,
            child: const Text('Restaurar playa, camping y bosque'),
          ),
        ),
        const SaveStatus(),
      ],
    );
  }

  String _tripLabel(AppController controller) {
    final trip = controller.trips.first;
    if (trip.destination.trim().isNotEmpty) return trip.destination.trim();
    if (trip.name.trim().isNotEmpty) return trip.name.trim();
    return 'Tu viaje';
  }

  PackingList? _current(List<PackingList> lists) {
    if (lists.isEmpty) return null;
    for (final list in lists) {
      if (list.id == _selectedId) return list;
    }
    return lists.first;
  }

  Future<void> _confirmDelete(String listId, String itemId, String name) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar elemento'),
          content: Text('Se va a quitar $name de la lista.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
          ],
        );
      },
    );
    if (remove == true && mounted) {
      await context.read<AppController>().deleteItem(listId, itemId);
    }
  }

  Future<void> _confirmRestore() async {
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restaurar plantillas'),
          content: const Text(
            'Playa, Camping y Bosque vuelven a su lista original y se desmarca lo empacado. Las listas con nombre propio se conservan.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restaurar')),
          ],
        );
      },
    );
    if (restore == true && mounted) {
      await context.read<AppController>().restorePresets();
    }
  }

  Future<void> _createList() async {
    final name = await askForName(context, title: 'Nueva lista', confirmLabel: 'Crear');
    if (name == null || !mounted) return;
    await context.read<AppController>().addList(name);
    if (!mounted) return;
    final lists = context.read<AppController>().lists;
    setState(() => _selectedId = lists.last.id);
  }

  Future<void> _addItem(String listId) async {
    final name = _itemController.text;
    if (name.trim().isEmpty) return;
    await context.read<AppController>().addItem(listId, name);
    _itemController.clear();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? forest : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? forest : line),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : forestDeep,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.name,
    required this.packed,
    required this.quantity,
    required this.onPacked,
    required this.onQuantity,
    required this.onRename,
    required this.onDelete,
  });

  final String name;
  final bool packed;
  final int quantity;
  final ValueChanged<bool> onPacked;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Semantics(
            button: true,
            checked: packed,
            label: packed ? '$name, empacado' : '$name, pendiente',
            child: InkWell(
            onTap: () => onPacked(!packed),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: packed ? forest : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: packed ? forest : const Color(0xFFC5CEC4), width: 1.4),
              ),
              child: packed ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: packed ? moss : forestDeep,
                decoration: packed ? TextDecoration.lineThrough : null,
                fontSize: 16,
              ),
            ),
          ),
          QuantityStepper(quantity: quantity, onChanged: onQuantity),
          PopupMenuButton<String>(
            tooltip: 'Más',
            icon: const Icon(Icons.more_horiz, color: moss, size: 18),
            onSelected: (value) {
              if (value == 'edit') onRename();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          tooltip: 'Menos',
          onPressed: quantity <= 1 ? null : () => onChanged(quantity - 1),
        ),
        SizedBox(
          width: 18,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, color: forestDeep),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          tooltip: 'Más',
          onPressed: quantity >= 99 ? null : () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: Icon(icon, size: 16, color: onPressed == null ? const Color(0xFFC5CEC4) : forest),
    );
  }
}
