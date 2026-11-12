import '../data/fuel_prices.dart';

class ExtraExpense {
  ExtraExpense({this.name = '', this.amount = ''});

  String name;
  String amount;

  Map<String, dynamic> toJson() => {'name': name, 'amount': amount};

  factory ExtraExpense.fromJson(Map<String, dynamic> json) {
    return ExtraExpense(
      name: json['name'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
    );
  }
}

class TripDraft {
  TripDraft({
    this.name = '',
    this.origin = '',
    this.destination = '',
    this.departDate = '',
    this.returnDate = '',
    this.includesReturn = true,
    this.distance = '',
    this.consumption = '',
    this.liters = '',
    this.fuelType = defaultFuelType,
    this.fuelPrice = '',
    this.tolls = '',
    this.otherExpenses = '',
    List<ExtraExpense>? extras,
    this.passengers = 1,
    this.budget = '',
  }) : extras = extras ?? [];

  String name;
  String origin;
  String destination;
  String departDate;
  String returnDate;
  bool includesReturn;
  String distance;
  String consumption;
  String liters;
  String fuelType;
  String fuelPrice;
  String tolls;
  String otherExpenses;
  List<ExtraExpense> extras;
  int passengers;
  String budget;

  String get title => name.trim().isEmpty ? 'Tu próximo viaje' : name.trim();

  /// Borrador sin destino y sin kilómetros: todavía no es un viaje escrito.
  bool get isBlankDraft => destination.trim().isEmpty && distance.trim().isEmpty;

  /// Viaje de muestra para quien abre la app con el borrador vacío.
  ///
  /// 240 km (ida y vuelta) / 12 km/L = 20 L × $1.400 = $28.000.
  /// Peajes $8.000 + snacks $6.000 = $42.000, o $14.000 por persona.
  factory TripDraft.example() {
    return TripDraft(
      name: 'Fin de semana en la costa',
      origin: 'Santiago',
      destination: 'Valparaíso',
      departDate: '13-11-2026',
      returnDate: '15-11-2026',
      includesReturn: true,
      distance: '240',
      consumption: '12',
      fuelType: defaultFuelType,
      fuelPrice: '1400',
      tolls: '8000',
      extras: [ExtraExpense(name: 'Snacks para el camino', amount: '6000')],
      passengers: 3,
      budget: '15000',
    );
  }

  String get route {
    final from = origin.trim();
    final to = destination.trim();
    if (from.isEmpty && to.isEmpty) return '';
    if (from.isEmpty) return to;
    if (to.isEmpty) return from;
    return '$from → $to';
  }

  String get dates {
    final start = departDate.trim();
    final end = returnDate.trim();
    if (start.isEmpty && end.isEmpty) return '';
    if (end.isEmpty) return start;
    if (start.isEmpty) return end;
    return '$start – $end';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'origin': origin,
        'destination': destination,
        'departDate': departDate,
        'returnDate': returnDate,
        'includesReturn': includesReturn,
        'distance': distance,
        'consumption': consumption,
        'liters': liters,
        'fuelType': fuelType,
        'fuelPrice': fuelPrice,
        'tolls': tolls,
        'otherExpenses': otherExpenses,
        'extras': extras.map((extra) => extra.toJson()).toList(),
        'passengers': passengers,
        'budget': budget,
      };

  factory TripDraft.fromJson(Map<String, dynamic> json) {
    final rawType = json['fuelType'] as String?;
    final known = fuelOptions.any((option) => option.name == rawType);
    final rawExtras = json['extras'] as List<dynamic>? ?? [];
    return TripDraft(
      name: json['name'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      departDate: json['departDate'] as String? ?? '',
      returnDate: json['returnDate'] as String? ?? '',
      includesReturn: json['includesReturn'] as bool? ?? true,
      distance: json['distance'] as String? ?? '',
      consumption: json['consumption'] as String? ?? '',
      liters: json['liters'] as String? ?? '',
      fuelType: known ? rawType! : defaultFuelType,
      fuelPrice: json['fuelPrice'] as String? ?? '',
      tolls: json['tolls'] as String? ?? '',
      otherExpenses: json['otherExpenses'] as String? ?? '',
      extras: rawExtras
          .map((entry) => ExtraExpense.fromJson(Map<String, dynamic>.from(entry as Map)))
          .toList(),
      passengers: json['passengers'] as int? ?? 1,
      budget: json['budget'] as String? ?? '',
    );
  }
}
