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
