import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/trip_calculator.dart';
import '../models/packing_item.dart';
import '../models/packing_list.dart';
import '../models/trip_draft.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/save_status.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onPrepare, required this.onExpenses});

  final VoidCallback onPrepare;
  final VoidCallback onExpenses;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final name = _firstName(controller.sessionName);
    final list = _featured(controller.lists);
    final trip = controller.trips.first;
    final preview = previewTrip(
      distance: trip.distance,
      consumption: trip.consumption,
      fuelPrice: trip.fuelPrice,
      tolls: trip.tolls,
      otherExpenses: trip.otherExpenses,
      extraAmounts: trip.extras.map((extra) => extra.amount).toList(),
      budget: trip.budget,
      passengers: trip.passengers,
    );
    final ready = preview is CostReady ? preview.result : null;
    final packed = list?.packedCount ?? 0;
    final total = list?.items.length ?? 0;
    final people = trip.passengers < 1 ? 1 : trip.passengers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      children: [
        Text(
          'Hola, $name',
          style: const TextStyle(
            fontFamily: displayFamily,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: forestDeep,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        _TripCard(
          trip: trip,
          people: people,
          onEdit: () => editTrip(context, trip),
          onContinue: onPrepare,
        ),
        const SizedBox(height: 22),
        const Text(
          'Todo listo para salir',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: forestDeep),
        ),
        const SizedBox(height: 2),
        const Text(
          'Un plan compartido. Cero errores.',
          style: TextStyle(color: moss, height: 1.3),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _PackedCard(packed: packed, total: total)),
            const SizedBox(width: 10),
            Expanded(child: _MoneyCard(result: ready, liters: litersFor(distance: trip.distance, consumption: trip.consumption))),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Que no se te quede nada',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: forestDeep.withValues(alpha: 0.92)),
        ),
        const SizedBox(height: 4),
        Text(
          _missingLine(list),
          style: const TextStyle(color: moss, height: 1.35),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onPrepare,
          style: FilledButton.styleFrom(
            backgroundColor: forest,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const FittedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Seguir preparando el viaje', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onExpenses,
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Ver gastos del viaje'),
            style: TextButton.styleFrom(foregroundColor: forestDeep),
          ),
        ),
        const SizedBox(height: 8),
        const SaveStatus(),
      ],
    );
  }

  static String _firstName(String? raw) {
    final name = (raw ?? '').trim();
    if (name.isEmpty) return 'viajero';
    return name.split(RegExp(r'\s+')).first;
  }

  static PackingList? _featured(List<PackingList> lists) {
    if (lists.isEmpty) return null;
    for (final list in lists) {
      if (list.items.any((item) => !item.packed)) return list;
    }
    return lists.first;
  }

  static String _missingLine(PackingList? list) {
    if (list == null || list.items.isEmpty) {
      return 'Elige una lista y marca lo que ya empacaste.';
    }
    final missing = list.items.where((item) => !item.packed).toList();
    if (missing.isEmpty) return 'La lista ${list.name} está completa.';
    final shown = missing.take(3).map((item) => _short(item)).toList();
    final rest = missing.length - shown.length;
    final listed = rest > 0 ? '${_join(shown)} y $rest más' : _join(shown);
    final noun = missing.length == 1 ? 'cosa' : 'cosas';
    return 'Te faltan ${missing.length} $noun: $listed.';
  }

  static String _short(PackingItem item) {
    final name = item.name.trim().toLowerCase();
    if (name.startsWith('bloqueador')) return 'bloqueador';
    if (name.startsWith('lentes')) return 'lentes';
    if (name.startsWith('cargador') || name.contains('celular')) return 'cargador';
    final words = name.split(' ');
    if (words.length <= 2) return name;
    return words.take(2).join(' ');
  }

  static String _join(List<String> names) {
    if (names.length == 1) return names.single;
    if (names.length == 2) return '${names[0]} y ${names[1]}';
    return '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.people,
    required this.onEdit,
    required this.onContinue,
  });

  final TripDraft trip;
  final int people;
  final VoidCallback onEdit;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final distance = trip.distance.trim();
    final meta = distance.isEmpty ? '$people personas' : '$people personas · $distance km';
    final route = trip.route;
    final dates = trip.dates;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/torres-paine.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment(0, -0.45),
              semanticLabel: 'Lago y montañas de Torres del Paine',
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x660A140F), Color(0xE60A140F)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'VIAJE EN GRUPO',
              style: TextStyle(
                color: Color(0xFFD7E3D4),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            trip.destination.trim().isNotEmpty ? trip.destination.trim() : trip.title,
            style: const TextStyle(
              fontFamily: displayFamily,
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(meta, style: const TextStyle(color: Color(0xFFD5E2D2))),
          if (route.isNotEmpty && trip.destination.trim().isEmpty) ...[
            const SizedBox(height: 4),
            Text(route, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
          if (trip.destination.trim().isNotEmpty && trip.origin.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Desde ${trip.origin.trim()}', style: const TextStyle(color: Color(0xFFD5E2D2))),
          ],
          if (dates.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(dates, style: const TextStyle(color: Color(0xFFD5E2D2))),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: forestDeep,
                  backgroundColor: lime,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(trip.name.trim().isEmpty && trip.destination.trim().isEmpty ? 'Crear viaje' : 'Editar viaje'),
              ),
              const Spacer(),
              Material(
                color: lime,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onContinue,
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.arrow_forward_rounded, color: forestDeep),
                  ),
                ),
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

Future<void> editTrip(BuildContext context, TripDraft trip) async {
  final name = TextEditingController(text: trip.name);
  final origin = TextEditingController(text: trip.origin);
  final destination = TextEditingController(text: trip.destination);
  final depart = TextEditingController(text: trip.departDate);
  final back = TextEditingController(text: trip.returnDate);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(trip.name.trim().isEmpty ? 'Crear viaje' : 'Editar viaje'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre del viaje')),
              TextField(controller: origin, decoration: const InputDecoration(labelText: 'Origen')),
              TextField(controller: destination, decoration: const InputDecoration(labelText: 'Destino')),
              TextField(
                controller: depart,
                decoration: const InputDecoration(labelText: 'Fecha de ida', hintText: '20-11-2026'),
              ),
              TextField(
                controller: back,
                decoration: const InputDecoration(labelText: 'Fecha de vuelta', hintText: '22-11-2026'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Guardar')),
        ],
      );
    },
  );
  if (saved == true && context.mounted) {
    final current = context.read<AppController>().trips.first;
    current.name = name.text.trim();
    current.origin = origin.text.trim();
    current.destination = destination.text.trim();
    current.departDate = depart.text.trim();
    current.returnDate = back.text.trim();
    await context.read<AppController>().updateTrips([current]);
  }
  name.dispose();
  origin.dispose();
  destination.dispose();
  depart.dispose();
  back.dispose();
}

class _PackedCard extends StatelessWidget {
  const _PackedCard({required this.packed, required this.total});

  final int packed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_2_outlined, color: forest, size: 20),
          const SizedBox(height: 10),
          const Text('Mi equipaje', style: TextStyle(color: moss, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            '$packed de $total',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: forestDeep),
          ),
          const Text('cosas empacadas', style: TextStyle(color: moss, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.result, required this.liters});

  final TripResult? result;
  final double? liters;

  @override
  Widget build(BuildContext context) {
    final amount = result == null ? '—' : formatMoney(result!.perPassenger);
    final note = _note(result);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_car_filled_outlined, color: forestDeep, size: 20),
          const SizedBox(height: 10),
          const Text('Por persona', style: TextStyle(color: forestDeep, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            amount,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: forestDeep),
          ),
          Text(note, style: const TextStyle(color: forestDeep, fontSize: 13)),
        ],
      ),
    );
  }

  String _note(TripResult? result) {
    if (liters != null) return 'Se necesitan ${formatDecimal(liters!)} litros';
    final difference = result?.budgetDifference;
    if (result == null) return 'Completa los gastos';
    if (difference == null) return 'Sin presupuesto';
    if (difference.round() >= 0) return 'Dentro del presupuesto';
    return 'Supera el presupuesto';
  }
}
