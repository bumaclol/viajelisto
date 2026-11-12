import 'dart:convert';

import 'package:http/http.dart' as http;

class RouteDistanceException implements Exception {
  const RouteDistanceException(this.message);

  final String message;
}

/// Kilómetros en auto entre dos lugares de Chile.
/// Usa OpenStreetMap y OSRM, que son públicos y gratuitos.
class RouteDistance {
  RouteDistance({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<double> kilometers({
    required String origin,
    required String destination,
    required bool roundTrip,
  }) async {
    try {
      final from = await _point(origin);
      final to = await _point(destination);
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${from.lon},${from.lat};${to.lon},${to.lat}?overview=false',
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const RouteDistanceException('El mapa no respondió.');
      }
      final body = jsonDecode(response.body);
      final routes = body is Map ? body['routes'] : null;
      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        throw const RouteDistanceException('No hay un camino en auto entre esos lugares.');
      }
      final meters = (routes.first['distance'] as num?)?.toDouble();
      if (meters == null || meters <= 0) {
        throw const RouteDistanceException('No hay un camino en auto entre esos lugares.');
      }
      final oneWay = meters / 1000;
      return roundTrip ? oneWay * 2 : oneWay;
    } on RouteDistanceException {
      rethrow;
    } catch (_) {
      throw const RouteDistanceException('No se pudo medir el trayecto.');
    }
  }

  Future<({double lat, double lon})> _point(String place) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'json',
      'limit': '1',
      'countrycodes': 'cl',
      'q': place,
    });
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw RouteDistanceException('No se encontró $place.');
    }
    final body = jsonDecode(response.body);
    if (body is! List || body.isEmpty || body.first is! Map) {
      throw RouteDistanceException('No se encontró $place en Chile.');
    }
    final item = body.first as Map;
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    if (lat == null || lon == null) {
      throw RouteDistanceException('No se encontró $place en Chile.');
    }
    return (lat: lat, lon: lon);
  }
}
