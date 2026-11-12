import 'dart:convert';

import '../models/packing_item.dart';
import '../models/packing_list.dart';
import '../models/trip_draft.dart';

bool sameTripPayload(
  List<PackingList> localLists,
  List<TripDraft> localTrips,
  List<PackingList> remoteLists,
  List<TripDraft> remoteTrips,
) {
  return jsonEncode(localLists.map((list) => list.toJson()).toList()) ==
          jsonEncode(remoteLists.map((list) => list.toJson()).toList()) &&
      jsonEncode(localTrips.map((trip) => trip.toJson()).toList()) ==
          jsonEncode(remoteTrips.map((trip) => trip.toJson()).toList());
}

String _keepLocal(String local, String remote) {
  return local.trim().isEmpty ? remote : local;
}

/// Conserva lo escrito en este navegador y agrega lo que solo está en la cuenta.
TripDraft mergeTrip(TripDraft local, TripDraft remote) {
  final seen = <String>{};
  final extras = <ExtraExpense>[];
  for (final extra in [...local.extras, ...remote.extras]) {
    final key = '${extra.name.trim()}|${extra.amount.trim()}';
    if (!seen.add(key)) continue;
    extras.add(ExtraExpense(name: extra.name, amount: extra.amount));
  }
  return TripDraft(
    name: _keepLocal(local.name, remote.name),
    origin: _keepLocal(local.origin, remote.origin),
    destination: _keepLocal(local.destination, remote.destination),
    departDate: _keepLocal(local.departDate, remote.departDate),
    returnDate: _keepLocal(local.returnDate, remote.returnDate),
    includesReturn: local.includesReturn || remote.includesReturn,
    distance: _keepLocal(local.distance, remote.distance),
    consumption: _keepLocal(local.consumption, remote.consumption),
    liters: _keepLocal(local.liters, remote.liters),
    fuelType: local.fuelType.trim().isEmpty ? remote.fuelType : local.fuelType,
    fuelPrice: _keepLocal(local.fuelPrice, remote.fuelPrice),
    tolls: _keepLocal(local.tolls, remote.tolls),
    otherExpenses: _keepLocal(local.otherExpenses, remote.otherExpenses),
    extras: extras,
    passengers: local.passengers <= 1 && remote.passengers > 1 ? remote.passengers : local.passengers,
    budget: _keepLocal(local.budget, remote.budget),
  );
}

List<PackingList> mergeLists(List<PackingList> local, List<PackingList> remote) {
  final merged = <String, PackingList>{
    for (final list in local) list.id: PackingList.fromJson(list.toJson()),
  };
  for (final list in remote) {
    final existing = merged[list.id];
    if (existing == null) {
      merged[list.id] = PackingList.fromJson(list.toJson());
      continue;
    }
    final ids = existing.items.map((item) => item.id).toSet();
    for (final item in list.items) {
      if (ids.contains(item.id)) continue;
      existing.items.add(PackingItem.fromJson(item.toJson()));
    }
  }
  return merged.values.toList();
}
