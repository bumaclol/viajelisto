import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/fuel_prices.dart';
import '../l10n/tr.dart';
import '../logic/trip_calculator.dart';
import '../models/fuel_station.dart';
import '../models/packing_list.dart';
import '../models/trip_draft.dart';
import '../screens/fuel_prices_screen.dart';
import '../screens/home_screen.dart';
import '../services/route_distance.dart';
import '../services/share_text.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/trip_cover.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late final TextEditingController _distance;
  late final TextEditingController _consumption;
  late final TextEditingController _fuelPrice;
  late final TextEditingController _tolls;
  late final TextEditingController _other;
  late final TextEditingController _passengers;
  late final TextEditingController _budget;
  final FocusNode _passengersFocus = FocusNode();
  final List<TextEditingController> _extraNames = [];
  final List<TextEditingController> _extraAmounts = [];
  var _includesReturn = true;
  var _fuelType = defaultFuelType;
  String? _priceNote;
  var _measuring = false;
  String? _measureError;

  @override
  void initState() {
    super.initState();
    final draft = context.read<AppController>().trips.first;
    _includesReturn = draft.includesReturn;
    _fuelType = draft.fuelType;
    for (final extra in draft.extras) {
      _extraNames.add(TextEditingController(text: extra.name));
      _extraAmounts.add(TextEditingController(text: extra.amount));
    }
    _distance = TextEditingController(text: draft.distance);
    _consumption = TextEditingController(text: draft.consumption);
    _fuelPrice = TextEditingController(text: draft.fuelPrice);
    _tolls = TextEditingController(text: draft.tolls);
    _other = TextEditingController(text: draft.otherExpenses);
    _passengers = TextEditingController(
      text: draft.passengers < 1 ? '1' : '${draft.passengers}',
    );
    _budget = TextEditingController(text: draft.budget);
    _passengersFocus.addListener(_syncPassengersField);
  }

  /// Al salir del campo, si quedó vacío o inválido, muestra el valor guardado
  /// para que lo visible coincida con lo que realmente se guardó.
  void _syncPassengersField() {
    if (_passengersFocus.hasFocus) return;
    final typed = int.tryParse(_passengers.text.trim());
    if (typed != null && typed >= 1) return;
    final saved = context.read<AppController>().trips.first.passengers;
    setState(() => _passengers.text = '${saved < 1 ? 1 : saved}');
  }

  @override
  void dispose() {
    _distance.dispose();
    _consumption.dispose();
    _fuelPrice.dispose();
    _tolls.dispose();
    _other.dispose();
    _passengers.dispose();
    _budget.dispose();
    _passengersFocus.dispose();
    for (final controller in _extraNames) {
      controller.dispose();
    }
    for (final controller in _extraAmounts) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passengers = int.tryParse(_passengers.text.trim()) ?? 0;
    final preview = previewTrip(
      distance: _distance.text,
      consumption: _consumption.text,
      fuelPrice: _fuelPrice.text,
      tolls: _tolls.text,
      otherExpenses: _other.text,
      extraAmounts: _extraAmounts.map((controller) => controller.text).toList(),
      budget: _budget.text,
      passengers: passengers,
    );

    final trip = context.watch<AppController>().trips.first;
    final listName = trip.title;

    final readyNow = preview is CostReady ? preview as CostReady : null;
    final shareNow = readyNow == null ? '\$0' : _shareNow(readyNow.result);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        const Text(
          'MI VIAJE EN EQUIPO',
          style: TextStyle(
            color: forest,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(context, 'Las cuentas, claras.'),
          style: TextStyle(
            fontFamily: displayFamily,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: forestDeep,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        TripCover(
          kicker: tr(context, 'Nuestro próximo viaje'),
          title: tr(context, 'Cada uno paga lo justo.'),
          onEdit: () => editTrip(context, trip),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Por persona', style: TextStyle(color: moss, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    shareNow,
                    style: const TextStyle(
                      fontFamily: displayFamily,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: forestDeep,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trip.destination.trim().isNotEmpty ? trip.destination.trim() : listName,
                  style: const TextStyle(color: moss, fontSize: 13),
                ),
                Text(
                  '${passengers < 1 ? 0 : passengers} pasajeros',
                  style: const TextStyle(color: moss, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Viaje y gastos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: forestDeep)),
                  SizedBox(height: 2),
                  Text('Las cuentas del grupo', style: TextStyle(color: moss)),
                ],
              ),
            ),
            Text('Moneda CLP', style: TextStyle(color: moss, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _includesReturn,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Los kilómetros incluyen ida y vuelta'),
          onChanged: (value) {
            setState(() => _includesReturn = value ?? false);
            _persist();
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _openFuelPrices,
            style: TextButton.styleFrom(foregroundColor: forest, padding: EdgeInsets.zero),
            icon: const Icon(Icons.local_gas_station_outlined, size: 18),
            label: const Text('Precios de combustible', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        if (_priceNote != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_priceNote!, style: const TextStyle(color: moss, height: 1.3)),
          ),
        const SizedBox(height: 8),
        _FormCard(
          distance: _distance,
          consumption: _consumption,
          fuelPrice: _fuelPrice,
          tolls: _tolls,
          other: _other,
          passengers: _passengers,
          passengersFocus: _passengersFocus,
          budget: _budget,
          onChanged: _onChanged,
        ),
        const SizedBox(height: 12),
        _ExtraExpenses(
          names: _extraNames,
          amounts: _extraAmounts,
          onChanged: _onChanged,
          onAdd: _addExtra,
          onRemove: _removeExtra,
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          preview: preview,
          liters: litersFor(distance: _distance.text, consumption: _consumption.text),
          from: trip.origin.trim(),
          to: trip.destination.trim(),
          roundTrip: _includesReturn,
          measuring: _measuring,
          measureError: _measureError,
          onMeasure: _measureRoute,
        ),
        const SizedBox(height: 16),
        _DetailCard(preview: preview),
      ],
    );
  }

  String _shareNow(TripResult result) {
    final shares = splitTotal(result.total.round(), result.passengers);
    if (shares.isEmpty) return formatMoney(result.perPassenger);
    if (shares.toSet().length == 1) return formatMoney(shares.first);
    return 'Desde ${formatMoney(shares.last)}';
  }

  void _onChanged(String _) => _persist();

  Future<void> _measureRoute() async {
    final trip = context.read<AppController>().trips.first;
    final origin = trip.origin.trim();
    final destination = trip.destination.trim();
    if (origin.isEmpty || destination.isEmpty) {
      setState(() {
        _measureError = 'Escribe el origen y el destino del viaje. Medir el camino no cuesta nada.';
      });
      return;
    }
    setState(() {
      _measuring = true;
      _measureError = null;
    });
    try {
      final km = await RouteDistance().kilometers(
        origin: origin,
        destination: destination,
        roundTrip: _includesReturn,
      );
      if (!mounted) return;
      setState(() {
        _distance.text = km.round().toString();
        _measuring = false;
      });
      _persist();
    } on RouteDistanceException catch (error) {
      if (!mounted) return;
      setState(() {
        _measuring = false;
        _measureError = '${error.message} Puedes escribir los kilómetros a mano. Sigue siendo gratis.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _measuring = false;
        _measureError = 'No se pudo medir el trayecto. Escríbelo en kilómetros. Sigue siendo gratis.';
      });
    }
  }

  Future<void> _openFuelPrices() async {
    final trip = context.read<AppController>().trips.first;
    final choice = await Navigator.of(context).push<SelectedFuelPrice>(
      MaterialPageRoute<SelectedFuelPrice>(
        builder: (_) => FuelPricesScreen(initialCommune: trip.destination),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() {
      _fuelPrice.text = '${choice.pesosPerLiter}';
      _fuelType = choice.fuelType;
      _priceNote = '${choice.stationName}, ${choice.address}: ${choice.pesosPerLiter} pesos por litro.';
    });
    _persist();
  }

  void _persist() {
    setState(() {});
    final passengers = int.tryParse(_passengers.text.trim());
    final current = context.read<AppController>().trips.first;
    context.read<AppController>().updateTrips([
      TripDraft(
        distance: _distance.text,
        consumption: _consumption.text,
        liters: current.liters,
        fuelType: _fuelType,
        fuelPrice: _fuelPrice.text,
        tolls: _tolls.text,
        otherExpenses: _other.text,
        extras: [
          for (var i = 0; i < _extraNames.length; i++)
            ExtraExpense(name: _extraNames[i].text, amount: _extraAmounts[i].text),
        ],
        passengers: passengers == null || passengers < 1 ? 1 : passengers,
        budget: _budget.text,
        name: current.name,
        origin: current.origin,
        destination: current.destination,
        departDate: current.departDate,
        returnDate: current.returnDate,
        includesReturn: _includesReturn,
      ),
    ]);
  }

  void _addExtra() {
    setState(() {
      _extraNames.add(TextEditingController());
      _extraAmounts.add(TextEditingController());
    });
    _persist();
  }

  Future<void> _removeExtra(int index) async {
    final name = _extraNames[index].text.trim();
    final label = name.isEmpty ? 'este gasto' : name;
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar gasto'),
          content: Text('Se va a quitar $label.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
          ],
        );
      },
    );
    if (remove != true || !mounted) return;
    setState(() {
      _extraNames.removeAt(index).dispose();
      _extraAmounts.removeAt(index).dispose();
    });
    _persist();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.preview,
    required this.liters,
    required this.from,
    required this.to,
    required this.roundTrip,
    required this.measuring,
    required this.measureError,
    required this.onMeasure,
  });

  final CostPreview preview;
  final double? liters;
  final String from;
  final String to;
  final bool roundTrip;
  final bool measuring;
  final String? measureError;
  final VoidCallback onMeasure;

  @override
  Widget build(BuildContext context) {
    final ready = preview is CostReady ? preview as CostReady : null;
    final result = ready?.result;
    final difference = result?.budgetDifference;
    final percent = _percent(result);
    final hint = switch (preview) {
      CostMissing(:final message) => message,
      CostInvalid(:final message) => message,
      CostReady() => '',
    };

    final budgetNote = result?.budget == null ? '' : ' · $percent% del presupuesto';
    final route = from.isEmpty && to.isEmpty
        ? 'Este trayecto'
        : from.isEmpty
            ? 'Hasta $to'
            : to.isEmpty
                ? 'Desde $from'
                : 'De $from a $to';
    final leg = roundTrip ? 'ida y vuelta' : 'solo ida';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route,
            style: const TextStyle(color: forestDeep, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          if (liters != null) ...[
            const Text(
              'SE NECESITAN',
              style: TextStyle(color: forestDeep, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6),
            ),
            const SizedBox(height: 2),
            Text(
              '${formatDecimal(liters!)} litros',
              style: const TextStyle(color: forestDeep, fontSize: 36, fontWeight: FontWeight.w800, height: 1),
            ),
            const SizedBox(height: 4),
            Text(
              leg,
              style: const TextStyle(color: forestDeep, fontWeight: FontWeight.w600),
            ),
          ] else
            Text(
              hint.isEmpty
                  ? 'Faltan los kilómetros y cuántos kilómetros rinde el auto por litro.'
                  : hint,
              style: const TextStyle(color: forestDeep, height: 1.4, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: measuring ? null : onMeasure,
              style: TextButton.styleFrom(foregroundColor: forestDeep, padding: EdgeInsets.zero),
              child: Text(
                measuring ? 'Midiendo el camino...' : 'Medir kilómetros del trayecto',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const Text(
            'El mapa es público y no cobra.',
            style: TextStyle(color: forestDeep, fontSize: 13),
          ),
          if (measureError != null) ...[
            const SizedBox(height: 6),
            Text(measureError!, style: const TextStyle(color: forestDeep, height: 1.3, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: forest, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cada uno paga', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  result == null ? '\$0' : _shareLabel(result),
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, height: 1),
                ),
                if (result != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'de ${formatMoney(result.total)} entre ${result.passengers}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 14),
            if (difference != null) ...[
              const SizedBox(height: 6),
              Text(
                difference.round() >= 0
                    ? 'Dentro del presupuesto: sobran ${formatMoney(difference)} por persona'
                    : 'Supera el presupuesto: faltan ${formatMoney(difference.abs())} por persona',
                style: const TextStyle(color: forestDeep, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Bencina ${formatMoney(result.fuelCost)} · peajes ${formatMoney(result.tolls)} · otros ${formatMoney(result.otherExpenses)}',
              style: const TextStyle(color: forestDeep, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${formatMoney(result.total)}$budgetNote',
              style: const TextStyle(color: forestDeep, fontWeight: FontWeight.w800),
            ),
            if (_remainderNote(result) != null) ...[
              const SizedBox(height: 6),
              Text(
                _remainderNote(result)!,
                style: const TextStyle(color: forestDeep, height: 1.3),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _shareLabel(TripResult result) {
    final shares = splitTotal(result.total.round(), result.passengers);
    if (shares.isEmpty) return formatMoney(result.perPassenger);
    if (shares.toSet().length == 1) return formatMoney(shares.first);
    return 'Desde ${formatMoney(shares.last)}';
  }

  String? _remainderNote(TripResult result) {
    final shares = splitTotal(result.total.round(), result.passengers);
    if (shares.toSet().length < 2) return null;
    final extra = result.total.round() % result.passengers;
    return 'El total no divide exacto: $extra ${extra == 1 ? 'persona paga' : 'personas pagan'} ${formatMoney(shares.first)} y el resto ${formatMoney(shares.last)}.';
  }

  int _percent(TripResult? result) {
    final limit = result?.budget;
    if (result == null || limit == null || limit <= 0) return 0;
    final value = ((result.perPassenger / limit) * 100).round();
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.distance,
    required this.consumption,
    required this.fuelPrice,
    required this.tolls,
    required this.other,
    required this.passengers,
    required this.passengersFocus,
    required this.budget,
    required this.onChanged,
  });

  final TextEditingController distance;
  final TextEditingController consumption;
  final TextEditingController fuelPrice;
  final TextEditingController tolls;
  final TextEditingController other;
  final TextEditingController passengers;
  final FocusNode passengersFocus;
  final TextEditingController budget;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              Expanded(child: _SoftField(controller: distance, label: 'Kilómetros', suffix: 'km', onChanged: onChanged)),
              const SizedBox(width: 12),
              Expanded(
                child: _SoftField(controller: consumption, label: 'Rendimiento', suffix: 'km/L', onChanged: onChanged),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SoftField(
                  controller: fuelPrice,
                  label: 'Precio bencina (\$/L)',
                  suffix: '/ L',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SoftField(
                  controller: passengers,
                  focusNode: passengersFocus,
                  label: 'Pasajeros',
                  helper: 'Incluye al conductor',
                  digitsOnly: true,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SoftField(controller: tolls, label: 'Peajes (\$)', suffix: 'CLP', onChanged: onChanged)),
              const SizedBox(width: 12),
              Expanded(
                child: _SoftField(
                  controller: other,
                  label: 'Otros gastos',
                  suffix: 'CLP',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SoftField(
            controller: budget,
            label: 'Presupuesto por persona (\$)',
            helper: 'Te avisamos si el viaje se pasa de este monto.',
            onChanged: onChanged,
          ),
        ],
    );
  }
}

enum _ShareChannel { whatsapp, mail }

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.preview});

  final CostPreview preview;

  @override
  Widget build(BuildContext context) {
    if (preview is! CostReady) return const SizedBox.shrink();
    final result = (preview as CostReady).result;
    final difference = result.budgetDifference;
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🧾', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('Detalle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _Line('Combustible necesario', '${formatDecimal(result.liters)} L'),
          _Line('Costo combustible', formatMoney(result.fuelCost)),
          _Line('Peajes', formatMoney(result.tolls)),
          _Line('Otros gastos', formatMoney(result.otherExpenses)),
          const Divider(height: 22),
          _Line('Total del viaje', formatMoney(result.total), strong: true),          if (difference != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  difference.round() >= 0 ? Icons.check_circle : Icons.error,
                  color: difference.round() >= 0 ? good : warn,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    difference.round() == 0
                        ? 'El costo por persona es igual a tu presupuesto.'
                        : difference.round() > 0
                            ? 'Te sobran ${formatMoney(difference)} por persona respecto de tu presupuesto.'
                            : 'Te pasas ${formatMoney(difference.abs())} por persona respecto de tu presupuesto.',
                    style: TextStyle(
                      color: difference.round() >= 0 ? good : warn,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'LISTO PARA EL GRUPO',
            style: TextStyle(
              color: moss,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final controller = context.watch<AppController>();
              final trip = controller.trips.first;
              final packed = controller.lists
                  .expand((list) => list.items)
                  .where((item) => item.packed)
                  .fold<int>(0, (sum, item) => sum + item.quantity);
              final label = trip.destination.trim().isEmpty ? trip.title : trip.destination.trim();
              final shares = splitTotal(result.total.round(), result.passengers);
              final share = shares.isEmpty
                  ? formatMoney(result.perPassenger)
                  : shares.toSet().length == 1
                      ? formatMoney(shares.first)
                      : 'desde ${formatMoney(shares.last)}';
              return Text(
                '$label: $share por persona. Empacados: $packed.',
                style: const TextStyle(color: forestDeep, height: 1.35, fontWeight: FontWeight.w600),
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showShareText(context, result),
              style: FilledButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: forestDeep,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text(
                'Compartir resumen',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _shareExternal(context, result, _ShareChannel.whatsapp),
                  style: FilledButton.styleFrom(
                    backgroundColor: forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text(tr(context, 'WhatsApp'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareExternal(context, result, _ShareChannel.mail),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: forestDeep,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: Text(tr(context, 'Correo'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareExternal(BuildContext context, TripResult result, _ShareChannel channel) {
    final controller = context.read<AppController>();
    final text = buildShareText(result, lists: controller.lists, trip: controller.trips.first);
    final encoded = Uri.encodeComponent(text);
    final url = channel == _ShareChannel.whatsapp
        ? 'https://wa.me/?text=$encoded'
        : 'mailto:?subject=${Uri.encodeComponent('Resumen del viaje')}&body=$encoded';
    openExternalUrl(url);
  }

  Future<void> _showShareText(BuildContext context, TripResult result) async {
    final controller = context.read<AppController>();
    final text = buildShareText(result, lists: controller.lists, trip: controller.trips.first);
    final shared = await sharePlainText(text);
    if (shared || !context.mounted) return;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resumen del viaje'),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Texto copiado al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar'),
          ),
        ],
      ),
    );
  }
}

/// Reparte el total en pesos enteros: si no divide exacto, los primeros
/// pasajeros pagan $1 más, de modo que la suma da exactamente el total.
List<int> splitTotal(int total, int passengers) {
  if (passengers < 1) return const [];
  final base = total ~/ passengers;
  final remainder = total % passengers;
  return List.generate(passengers, (i) => i < remainder ? base + 1 : base);
}

String _shownAmount(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return r'$0';
  final normalized = text.contains(',')
      ? text.replaceAll('.', '').replaceAll(',', '.')
      : (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text) ? text.replaceAll('.', '') : text);
  final value = double.tryParse(normalized);
  if (value == null) return text;
  return formatMoney(value);
}

/// Texto listo para copiar con el equipaje marcado, el total y lo que paga cada pasajero.
String buildShareText(
  TripResult result, {
  List<PackingList> lists = const [],
  TripDraft? trip,
}) {
  final total = result.total.round();
  final shares = splitTotal(total, result.passengers);
  final buffer = StringBuffer()..writeln('🚗 Resumen del viaje');
  if (trip != null && trip.name.trim().isNotEmpty) buffer.writeln(trip.name.trim());
  if (trip != null && trip.route.isNotEmpty) buffer.writeln(trip.route);
  if (trip != null && trip.dates.isNotEmpty) buffer.writeln(trip.dates);
  if (trip != null) {
    buffer.writeln(
      trip.includesReturn
          ? 'Los kilómetros incluyen ida y vuelta.'
          : 'Los kilómetros son solo de ida.',
    );
  }
  buffer.writeln();
  final packed = <String>[];
  for (final list in lists) {
    for (final item in list.items) {
      if (!item.packed) continue;
      packed.add(item.quantity > 1 ? '• ${item.name} x${item.quantity}' : '• ${item.name}');
    }
  }
  if (packed.isNotEmpty) {
    buffer
      ..writeln('Equipaje marcado:')
      ..writeln(packed.join('\n'))
      ..writeln();
  }
  buffer
    ..writeln('Gastos:')
    ..writeln('• Combustible (${formatDecimal(result.liters)} L): ${formatMoney(result.fuelCost)}')
    ..writeln('• Peajes: ${formatMoney(result.tolls)}');
  final extras = trip?.extras ?? const <ExtraExpense>[];
  if (extras.isEmpty) {
    buffer.writeln('• Otros gastos: ${formatMoney(result.otherExpenses)}');
  } else {
    for (final extra in extras) {
      final label = extra.name.trim().isEmpty ? 'Gasto' : extra.name.trim();
      buffer.writeln('• $label: ${_shownAmount(extra.amount)}');
    }
    final unnamed = trip?.otherExpenses.trim() ?? '';
    if (unnamed.isNotEmpty) buffer.writeln('• Otros gastos: $unnamed');
  }
  buffer
    ..writeln()
    ..writeln('Total del viaje: ${formatMoney(total)}')
    ..writeln()
    ..writeln('Pasajeros (${result.passengers}):');
  for (var i = 0; i < shares.length; i++) {
    final label = i == 0 ? 'Pasajero 1 (conductor)' : 'Pasajero ${i + 1}';
    buffer.writeln('• $label: ${formatMoney(shares[i])}');
  }
  if (shares.toSet().length > 1) {
    final firstCount = total % result.passengers;
    buffer
      ..writeln()
      ..writeln(
        'El total no se divide exacto: $firstCount ${firstCount == 1 ? 'persona paga' : 'personas pagan'} '
        '${formatMoney(shares.first)} y el resto ${formatMoney(shares.last)}, para que la suma sea ${formatMoney(total)}.',
      );
  }
  if (result.withinBudget == true) {
    buffer.writeln('Dentro del presupuesto por persona (${formatMoney(result.budget!)}).');
  } else if (result.withinBudget == false) {
    buffer.writeln('Supera el presupuesto por persona (${formatMoney(result.budget!)}).');
  }
  return buffer.toString().trimRight();
}

class _ExtraExpenses extends StatelessWidget {
  const _ExtraExpenses({
    required this.names,
    required this.amounts,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TextEditingController> names;
  final List<TextEditingController> amounts;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Otros gastos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Cada gasto lleva nombre y monto. El monto tiene que ser 0 o más.',
            style: TextStyle(color: moss, height: 1.3),
          ),
          const SizedBox(height: 12),
          if (names.isEmpty)
            const Text('Todavía no hay gastos con nombre.', style: TextStyle(color: moss)),
          for (var i = 0; i < names.length; i++) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: names[i],
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: amounts[i],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Monto', suffixText: 'CLP'),
                    onChanged: onChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar gasto',
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Agregar gasto'),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      fontSize: strong ? 16 : 15,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x12305080), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

class _SoftField extends StatelessWidget {
  const _SoftField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.focusNode,
    this.helper,
    this.suffix,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? helper;
  final String? suffix;
  final bool digitsOnly;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: moss, fontSize: 13)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: forestDeep),
          keyboardType: digitsOnly
              ? TextInputType.number
              : const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.start,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              digitsOnly ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
            ),
            // Sin ceros a la izquierda: el campo nunca muestra "0" ni "05".
            if (digitsOnly) FilteringTextInputFormatter.deny(RegExp(r'^0+')),
          ],
          decoration: InputDecoration(
            isDense: true,
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: onChanged,
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper!, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12)),
        ],
      ],
    );
  }
}
