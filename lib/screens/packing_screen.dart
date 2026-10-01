import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/packing_list.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/list_visual.dart';
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            const Text(
              'Listas de equipaje',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
            ),
            const Spacer(),
            Text(
              '${lists.length} LISTAS',
              style: const TextStyle(
                color: blue,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final list in lists)
                  SizedBox(
                    width: width,
                    child: _ListTile(
                      list: list,
                      selected: selected?.id == list.id,
                      onTap: () => setState(() => _selectedId = list.id),
                    ),
                  ),
                SizedBox(
                  width: width,
                  child: _NewListTile(onTap: _createList),
                ),
              ],
            );
          },
        ),
        if (selected != null) ...[
          const SizedBox(height: 16),
          _DetailCard(
            list: selected,
            itemController: _itemController,
            onAdd: () => _addItem(selected.id),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: controller.restorePresets,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restaurar playa, camping y bosque'),
          ),
        ),
      ],
    );
  }

  PackingList? _current(List<PackingList> lists) {
    if (lists.isEmpty) return null;
    for (final list in lists) {
      if (list.id == _selectedId) return list;
    }
    return lists.first;
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

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.list,
    required this.selected,
    required this.onTap,
  });

  final PackingList list;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = visualFor(list.iconKey);
    final total = list.items.length;
    final packed = list.packedCount;
    return Material(
      color: visual.background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? blue : visual.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(visual.icon, color: visual.color, size: 20),
              ),
              const Spacer(),
              Text(
                list.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
              ),
              Text(
                '$packed/$total listos',
                style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewListTile extends StatelessWidget {
  const _NewListTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 118,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD5DDEA), width: 1.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Nueva lista...', style: TextStyle(color: Color(0xFF667085))),
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: blue, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.list,
    required this.itemController,
    required this.onAdd,
  });

  final PackingList list;
  final TextEditingController itemController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final visual = visualFor(list.iconKey);
    final total = list.items.length;
    final packed = list.packedCount;
    final percent = total == 0 ? 0 : ((packed / total) * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x12305080), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(visual.icon, color: visual.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  list.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Cambiar nombre',
                onPressed: () async {
                  final name = await askForName(
                    context,
                    title: 'Cambiar nombre',
                    initial: list.name,
                  );
                  if (name == null || !context.mounted) return;
                  await context.read<AppController>().renameList(list.id, name);
                },
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$packed de $total elementos empacados ($percent%)',
              style: const TextStyle(color: Color(0xFF667085)),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : packed / total,
              minHeight: 6,
              backgroundColor: const Color(0xFFE8EDF5),
              color: blue,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: itemController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Agregar elemento...'),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  minimumSize: const Size(96, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in list.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: item.packed,
                        activeColor: blue,
                        onChanged: (value) {
                          context.read<AppController>().toggleItem(list.id, item.id, value ?? false);
                        },
                      ),
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            decoration: item.packed ? TextDecoration.lineThrough : null,
                            color: item.packed ? const Color(0xFF98A2B3) : ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      QuantityStepper(
                        quantity: item.quantity,
                        onChanged: (value) {
                          context.read<AppController>().setItemQuantity(list.id, item.id, value);
                        },
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final name = await askForName(
                            context,
                            title: 'Editar elemento',
                            initial: item.name,
                          );
                          if (name == null || !context.mounted) return;
                          await context.read<AppController>().renameItem(list.id, item.id, name);
                        },
                        child: const Text('Editar'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => context.read<AppController>().deleteItem(list.id, item.id),
                        child: const Text('Eliminar', style: TextStyle(color: Color(0xFF98A2B3))),
                      ),
                    ],
                  ),
                ],
              ),
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
          width: 22,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
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
      icon: Icon(icon, size: 18, color: onPressed == null ? const Color(0xFF98A2B3) : blue),
    );
  }
}
