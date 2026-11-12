import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/fuel_station.dart';

class FuelCatalogStore {
  static const cacheKey = 'cne_fuel_catalog_v1';
  static const freshFor = Duration(hours: 6);

  Future<FuelCatalog?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final catalog = FuelCatalog.fromJson(Map<String, dynamic>.from(json));
      if (catalog.stations.isEmpty) return null;
      return catalog;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(FuelCatalog catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cacheKey, jsonEncode(catalog.toJson()));
  }

  bool isFresh(FuelCatalog catalog, DateTime now) {
    return now.difference(catalog.fetchedAt) < freshFor;
  }
}
