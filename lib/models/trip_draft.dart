import '../data/fuel_prices.dart';

class TripDraft {
  TripDraft({
    this.distance = '',
    this.consumption = '',
    this.liters = '',
    this.fuelType = defaultFuelType,
    this.fuelPrice = '',
    this.tolls = '',
    this.otherExpenses = '',
    this.passengers = 1,
    this.budget = '',
  });

  String distance;
  String consumption;
  String liters;
  String fuelType;
  String fuelPrice;
  String tolls;
  String otherExpenses;
  int passengers;
  String budget;

  Map<String, dynamic> toJson() => {
        'distance': distance,
        'consumption': consumption,
        'liters': liters,
        'fuelType': fuelType,
        'fuelPrice': fuelPrice,
        'tolls': tolls,
        'otherExpenses': otherExpenses,
        'passengers': passengers,
        'budget': budget,
      };

  factory TripDraft.fromJson(Map<String, dynamic> json) {
    final rawType = json['fuelType'] as String?;
    final known = fuelOptions.any((option) => option.name == rawType);
    return TripDraft(
      distance: json['distance'] as String? ?? '',
      consumption: json['consumption'] as String? ?? '',
      liters: json['liters'] as String? ?? '',
      fuelType: known ? rawType! : defaultFuelType,
      fuelPrice: json['fuelPrice'] as String? ?? '',
      tolls: json['tolls'] as String? ?? '',
      otherExpenses: json['otherExpenses'] as String? ?? '',
      passengers: json['passengers'] as int? ?? 1,
      budget: json['budget'] as String? ?? '',
    );
  }
}
