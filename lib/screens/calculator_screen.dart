import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic/trip_calculator.dart';
import '../models/trip_draft.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

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

  @override
  void initState() {
    super.initState();
    final draft = context.read<AppController>().trips.first;
    _distance = TextEditingController(text: draft.distance);
    _consumption = TextEditingController(text: draft.consumption);
    _fuelPrice = TextEditingController(text: draft.fuelPrice);
    _tolls = TextEditingController(text: draft.tolls);
    _other = TextEditingController(text: draft.otherExpenses);
    _passengers = TextEditingController(
      text: draft.passengers < 1 ? '1' : '${draft.passengers}',
    );
    _budget = TextEditingController(text: draft.budget);
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
      budget: _budget.text,
      passengers: passengers < 1 ? 0 : passengers,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _SummaryCard(preview: preview),
        const SizedBox(height: 16),
        _FormCard(
          distance: _distance,
          consumption: _consumption,
          fuelPrice: _fuelPrice,
          tolls: _tolls,
          other: _other,
          passengers: _passengers,
          budget: _budget,
          onChanged: _onChanged,
        ),
        const SizedBox(height: 16),
        _DetailCard(preview: preview),
      ],
    );
  }

  void _onChanged(String _) => _persist();

  void _persist() {
    setState(() {});
    final passengers = int.tryParse(_passengers.text.trim());
    final current = context.read<AppController>().trips.first;
    context.read<AppController>().updateTrips([
      TripDraft(
        distance: _distance.text,
        consumption: _consumption.text,
        liters: current.liters,
        fuelType: current.fuelType,
        fuelPrice: _fuelPrice.text,
        tolls: _tolls.text,
        otherExpenses: _other.text,
        passengers: passengers == null || passengers < 1 ? 1 : passengers,
        budget: _budget.text,
      ),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.preview});

  final CostPreview preview;

  @override
  Widget build(BuildContext context) {
    final ready = preview is CostReady ? preview as CostReady : null;
    final result = ready?.result;
    final within = result?.withinBudget;
    final difference = result?.budgetDifference;
    final percent = _percent(result);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(24),
      ),
      child: result == null
          ? const Text(
              'Completa distancia, rendimiento y precio para ver el gasto.',
              style: TextStyle(color: Colors.white, height: 1.4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'GASTO TOTAL',
                      style: TextStyle(
                        color: Color(0xFF98A2B3),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    if (within != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: within ? blue : warn,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          within ? 'EN PRESUPUESTO' : 'SOBRE PRESUPUESTO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatMoney(result.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (result.budget != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Presupuesto: ${formatMoney(result.budget!)} c/u',
                          style: const TextStyle(color: Color(0xFF98A2B3)),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 7,
                      backgroundColor: const Color(0xFF344054),
                      color: within == false ? warn : const Color(0xFF3D8BFF),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Stat('PASAJEROS', '${result.passengers} personas'),
                    ),
                    Expanded(
                      child: _Stat('POR PERSONA', formatMoney(result.perPassenger), accent: true),
                    ),
                  ],
                ),
                if (difference != null) const SizedBox(height: 4),
              ],
            ),
    );
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: accent ? const Color(0xFF5B9BFF) : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
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
    required this.budget,
    required this.onChanged,
  });

  final TextEditingController distance;
  final TextEditingController consumption;
  final TextEditingController fuelPrice;
  final TextEditingController tolls;
  final TextEditingController other;
  final TextEditingController passengers;
  final TextEditingController budget;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Color(0xFFE25B5B), size: 20),
              SizedBox(width: 8),
              Text('Datos del viaje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _SoftField(controller: distance, label: 'Distancia (km)', onChanged: onChanged)),
              const SizedBox(width: 12),
              Expanded(
                child: _SoftField(controller: consumption, label: 'Rendimiento (km/L)', onChanged: onChanged),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SoftField(
                  controller: fuelPrice,
                  label: 'Precio combustible (por litro)',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _SoftField(controller: tolls, label: 'Peajes (total)', onChanged: onChanged)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SoftField(
                  controller: other,
                  label: 'Otros gastos',
                  helper: 'Estacionamiento, comida, etc.',
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SoftField(
                  controller: passengers,
                  label: 'Pasajeros',
                  helper: 'Incluye al conductor',
                  digitsOnly: true,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SoftField(
            controller: budget,
            label: 'Presupuesto por persona',
            helper: 'Te avisamos si el viaje se pasa de este monto.',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.preview});

  final CostPreview preview;

  @override
  Widget build(BuildContext context) {
    if (preview is! CostReady) {
      final message = preview is CostMissing
          ? (preview as CostMissing).message
          : (preview as CostInvalid).message;
      return _WhiteCard(child: Text(message, style: const TextStyle(height: 1.4)));
    }
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
          _Line('Total del viaje', formatMoney(result.total), strong: true),
          if (difference != null) ...[
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
    this.helper,
    this.digitsOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;
  final bool digitsOnly;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF344054))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              digitsOnly ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
            ),
          ],
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
