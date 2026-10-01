import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_controller.dart';
import '../widgets/list_visual.dart';
import '../widgets/name_dialog.dart';

class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final _itemController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final list = controller.listById(widget.listId);

    if (list == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final visual = visualFor(list.iconKey);

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(visual.icon, color: visual.color),
                const SizedBox(width: 8),
                Text(
                  list.items.isEmpty
                      ? 'Agrega el primer elemento'
                      : '${list.packedCount} de ${list.items.length} empacados',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Esta lista está vacía. Escribe un elemento abajo y quedará guardado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: list.items.length,
                    itemBuilder: (context, index) {
                      final item = list.items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB42318),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          context.read<AppController>().deleteItem(list.id, item.id);
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          child: CheckboxListTile(
                            value: item.packed,
                            activeColor: visual.color,
                            title: Text(
                              item.name,
                              style: TextStyle(
                                decoration:
                                    item.packed ? TextDecoration.lineThrough : null,
                                color: item.packed ? const Color(0xFF7A858E) : null,
                              ),
                            ),
                            secondary: IconButton(
                              tooltip: 'Editar',
                              onPressed: () async {
                                final name = await askForName(
                                  context,
                                  title: 'Editar elemento',
                                  initial: item.name,
                                );
                                if (name == null || !context.mounted) return;
                                await context
                                    .read<AppController>()
                                    .renameItem(list.id, item.id, name);
                              },
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            onChanged: (value) {
                              context
                                  .read<AppController>()
                                  .toggleItem(list.id, item.id, value ?? false);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Agregar elemento',
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _addItem,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(52, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem() async {
    final name = _itemController.text;
    if (name.trim().isEmpty) return;
    await context.read<AppController>().addItem(widget.listId, name);
    _itemController.clear();
  }
}
