import 'package:flutter_test/flutter_test.dart';
import 'package:viajelisto/logic/trip_calculator.dart';

void main() {
  test('reparte combustible y peajes entre los pasajeros', () {
    final preview = previewTrip(
      distance: '100',
      consumption: '10',
      fuelPrice: '1000',
      tolls: '5000',
      budget: '20000',
      passengers: 2,
    );

    expect(preview, isA<CostReady>());
    final result = (preview as CostReady).result;
    expect(result.liters, 10);
    expect(result.fuelCost, 10000);
    expect(result.total, 15000);
    expect(result.perPassenger, 7500);
    expect(result.withinBudget, isTrue);
    expect(result.budgetDifference, 12500);
  });

  test('avisa cuando el costo supera el presupuesto', () {
    final preview = previewTrip(
      distance: '100',
      consumption: '10',
      fuelPrice: '1000',
      tolls: '5000',
      budget: '5000',
      passengers: 2,
    );

    final result = (preview as CostReady).result;
    expect(result.withinBudget, isFalse);
    expect(result.budgetDifference, -2500);
  });

  test('acepta coma decimal y deja los peajes en cero si están vacíos', () {
    final preview = previewTrip(
      distance: '150',
      consumption: '12,5',
      fuelPrice: '1.290',
      tolls: '',
      budget: '',
      passengers: 4,
    );

    final result = (preview as CostReady).result;
    expect(result.liters, closeTo(12, 0.001));
    expect(result.fuelCost, closeTo(15480, 0.001));
    expect(result.tolls, 0);
    expect(result.budget, isNull);
    expect(result.withinBudget, isNull);
    expect(result.perPassenger, closeTo(result.total / 4, 0.001));
  });

  test('rechaza el cálculo si falta la cantidad o la distancia con rendimiento', () {
    final preview = previewTrip(
      distance: '100',
      consumption: '0',
      fuelPrice: '1000',
      tolls: '',
      budget: '',
      passengers: 1,
    );

    expect(preview, isA<CostMissing>());
  });

  test('usa los litros ingresados y el precio del combustible', () {
    final preview = previewTrip(
      distance: '999',
      consumption: '12',
      liters: '10',
      fuelPrice: '1600',
      tolls: '6000',
      budget: '',
      passengers: 4,
    );

    final result = (preview as CostReady).result;
    expect(result.liters, 10);
    expect(result.fuelCost, 16000);
    expect(result.total, 22000);
    expect(result.perPassenger, 5500);
  });

  test('si hay litros y no hay rendimiento, asume 10 km por litro', () {
    final preview = previewTrip(
      distance: '',
      consumption: '',
      liters: '8',
      fuelPrice: '1400',
      tolls: '',
      budget: '',
      passengers: 1,
    );

    final result = (preview as CostReady).result;
    expect(result.liters, 8);
    expect(result.fuelCost, 11200);
  });

  test('el total igual al presupuesto sigue dentro', () {
    final preview = previewTrip(
      distance: '10',
      consumption: '10',
      fuelPrice: '1000',
      tolls: '0',
      budget: '1000',
      passengers: 1,
    );

    expect((preview as CostReady).result.withinBudget, isTrue);
  });
}
