/// Resultado del costo de un viaje compartido en auto.
///
/// Litros = distancia / rendimiento (km por litro).
/// Combustible = litros × precio por litro.
/// Total = combustible + peajes + otros gastos.
/// Por pasajero = total / pasajeros.
/// El presupuesto se compara por persona.
class TripResult {
  const TripResult({
    required this.liters,
    required this.fuelCost,
    required this.tolls,
    required this.otherExpenses,
    required this.total,
    required this.perPassenger,
    required this.passengers,
    required this.budget,
  });

  final double liters;
  final double fuelCost;
  final double tolls;
  final double otherExpenses;
  final double total;
  final double perPassenger;
  final int passengers;

  /// Presupuesto por persona.
  final double? budget;

  bool? get withinBudget {
    final limit = budget;
    if (limit == null) return null;
    return perPassenger <= limit;
  }

  /// Positivo: dinero que sobra por persona. Negativo: dinero que falta.
  double? get budgetDifference {
    final limit = budget;
    if (limit == null) return null;
    return limit - perPassenger;
  }
}

sealed class CostPreview {}

class CostMissing extends CostPreview {
  CostMissing(this.message);
  final String message;
}

class CostInvalid extends CostPreview {
  CostInvalid(this.message);
  final String message;
}

class CostReady extends CostPreview {
  CostReady(this.result);
  final TripResult result;
}

CostPreview previewTrip({
  required String distance,
  required String consumption,
  required String fuelPrice,
  required String tolls,
  required String budget,
  required int passengers,
  String liters = '',
  String otherExpenses = '',
}) {
  final distanceValue = _read(distance, allowEmpty: true);
  final consumptionValue = _read(consumption, allowEmpty: true);
  final litersValue = _read(liters, allowEmpty: true);
  final priceValue = _read(fuelPrice);
  final tollValue = _read(tolls, allowEmpty: true);
  final otherValue = _read(otherExpenses, allowEmpty: true);
  final budgetValue = _read(budget, allowEmpty: true, emptyMeansNull: true);

  final reads = [
    distanceValue,
    consumptionValue,
    litersValue,
    priceValue,
    tollValue,
    otherValue,
    budgetValue,
  ];
  if (reads.any((read) => read.invalid)) {
    return CostInvalid('Revisa los números. Ejemplo: 12,5 o 1.350.');
  }
  if (passengers < 1) {
    return CostInvalid('Tiene que haber al menos 1 pasajero.');
  }
  if (priceValue.empty) {
    return CostMissing(
      'Ingresa la distancia, el rendimiento y el precio del combustible.',
    );
  }

  final price = priceValue.value!;
  final toll = tollValue.value ?? 0;
  final other = otherValue.value ?? 0;
  final limit = budgetValue.value;
  if (price < 0 || toll < 0 || other < 0 || (limit != null && limit < 0)) {
    return CostInvalid('Usa solo cantidades desde 0 hacia arriba.');
  }

  final enteredLiters = litersValue.value ?? 0;
  final enteredDistance = distanceValue.value ?? 0;
  final enteredConsumption = consumptionValue.value ?? 0;
  if (enteredLiters < 0 || enteredDistance < 0 || enteredConsumption < 0) {
    return CostInvalid('Usa solo cantidades desde 0 hacia arriba.');
  }

  final double km;
  final double kmPerLiter;
  if (enteredLiters > 0) {
    kmPerLiter = enteredConsumption > 0 ? enteredConsumption : 10;
    km = enteredLiters * kmPerLiter;
  } else if (enteredDistance > 0 && enteredConsumption > 0) {
    km = enteredDistance;
    kmPerLiter = enteredConsumption;
  } else {
    return CostMissing(
      'Ingresa la cantidad de combustible, o la distancia y el rendimiento.',
    );
  }

  final usedLiters = km / kmPerLiter;
  final fuelCost = usedLiters * price;
  final total = fuelCost + toll + other;

  return CostReady(
    TripResult(
      liters: usedLiters,
      fuelCost: fuelCost,
      tolls: toll,
      otherExpenses: other,
      total: total,
      perPassenger: total / passengers,
      passengers: passengers,
      budget: limit,
    ),
  );
}

class _Parsed {
  const _Parsed({
    required this.empty,
    required this.invalid,
    this.value,
  });

  final bool empty;
  final bool invalid;
  final double? value;
}

_Parsed _read(
  String raw, {
  bool allowEmpty = false,
  bool emptyMeansNull = false,
}) {
  final text = raw.trim().replaceAll(' ', '');
  if (text.isEmpty) {
    if (!allowEmpty) {
      return const _Parsed(empty: true, invalid: false);
    }
    return _Parsed(
      empty: true,
      invalid: false,
      value: emptyMeansNull ? null : 0,
    );
  }

  final parsed = double.tryParse(_normalize(text));
  if (parsed == null || parsed.isNaN || parsed.isInfinite) {
    return const _Parsed(empty: false, invalid: true);
  }
  return _Parsed(empty: false, invalid: false, value: parsed);
}

/// Coma decimal (12,5). El punto de miles chileno (1.350) también vale.
String _normalize(String text) {
  if (text.contains(',')) {
    return text.replaceAll('.', '').replaceAll(',', '.');
  }
  if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(text)) {
    return text.replaceAll('.', '');
  }
  return text;
}
