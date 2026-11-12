import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/fuel_station.dart';

class FuelCatalogException implements Exception {
  const FuelCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CneFuelApi {
  CneFuelApi({http.Client? client}) : _client = client ?? http.Client();

  static final stationsUri = Uri.parse('https://api.bencinaenlinea.cl/api/busqueda_estacion_filtro');
  static final brandsUri = Uri.parse('https://api.bencinaenlinea.cl/api/marca_ciudadano');

  final http.Client _client;

  Future<FuelCatalog> fetch() async {
    try {
      final responses = await Future.wait([
        _get(stationsUri),
        _get(brandsUri),
      ]);
      final catalog = parseCneCatalog(responses[0], responses[1], DateTime.now());
      if (catalog.stations.isEmpty) {
        throw const FuelCatalogException(
          'Bencina en Línea respondió sin estaciones. Los precios no pudieron actualizarse.',
        );
      }
      return catalog;
    } on FuelCatalogException {
      rethrow;
    } catch (_) {
      throw const FuelCatalogException(
        'No hay conexión con Bencina en Línea. Los precios no pudieron actualizarse.',
      );
    }
  }

  Future<String> _get(Uri uri) async {
    final response = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw const FuelCatalogException(
        'Bencina en Línea no respondió. Los precios no pudieron actualizarse.',
      );
    }
    return response.body;
  }
}

FuelCatalog parseCneCatalog(String stationsBody, String brandsBody, DateTime fetchedAt) {
  final brands = _brandNames(brandsBody);
  final root = jsonDecode(stationsBody);
  final raw = root is Map && root['data'] is List ? root['data'] as List : const [];
  final stations = <FuelStation>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final station = _station(Map<String, dynamic>.from(item), brands);
    if (station.region.isEmpty || station.commune.isEmpty) continue;
    if (station.prices.isEmpty) continue;
    stations.add(station);
  }
  return FuelCatalog(fetchedAt: fetchedAt, stations: stations);
}

Map<int, String> _brandNames(String body) {
  final names = <int, String>{};
  try {
    final root = jsonDecode(body);
    final raw = root is List
        ? root
        : root is Map && root['data'] is List
            ? root['data'] as List
            : const [];
    for (final item in raw) {
      if (item is! Map) continue;
      final id = (item['id'] as num?)?.round();
      final name = (item['nombre'] as String?)?.trim() ?? '';
      if (id != null && name.isNotEmpty) names[id] = name;
    }
  } catch (_) {
    return names;
  }
  return names;
}

FuelStation _station(Map<String, dynamic> json, Map<int, String> brands) {
  final brandId = (json['marca'] as num?)?.round();
  final rawPrices = json['combustibles'];
  final prices = <FuelPricePoint>[];
  if (rawPrices is List) {
    for (final item in rawPrices) {
      if (item is! Map) continue;
      final price = double.tryParse('${item['precio'] ?? ''}');
      final code = (item['nombre_corto'] as String?)?.trim() ?? '';
      if (price == null || price <= 0 || code.isEmpty) continue;
      prices.add(
        FuelPricePoint(
          code: code,
          pesosPerLiter: price.round(),
          updatedAt: (item['precio_fecha'] as String?)?.trim() ?? '',
          service: (item['tipo_atencion_nombre'] as String?)?.trim() ?? '',
        ),
      );
    }
  }
  return FuelStation(
    id: (json['id'] as num?)?.round() ?? 0,
    brand: brands[brandId] ?? '',
    address: (json['direccion'] as String?)?.trim() ?? '',
    region: (json['region'] as String?)?.trim() ?? '',
    commune: (json['comuna'] as String?)?.trim() ?? '',
    prices: prices,
  );
}
