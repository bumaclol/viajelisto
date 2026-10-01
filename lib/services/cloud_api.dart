import 'dart:convert';

import 'package:http/http.dart' as http;

class CloudReply {
  const CloudReply({this.error, this.data});

  final String? error;
  final Map<String, dynamic>? data;
}

class CloudApi {
  CloudApi(this.baseUrl);

  final String baseUrl;
  String? token;

  Future<CloudReply> get(String path) => _send('GET', path, null);

  Future<CloudReply> post(String path, Map<String, dynamic> body) => _send('POST', path, body);

  Future<CloudReply> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body);

  Future<CloudReply> put(String path, Map<String, dynamic> body) => _send('PUT', path, body);

  Future<CloudReply> _send(String method, String path, Map<String, dynamic>? body) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers['Content-Type'] = 'application/json';
      final current = token;
      if (current != null && current.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $current';
      }
      if (body != null) request.body = jsonEncode(body);
      final streamed = await request.send().timeout(const Duration(seconds: 8));
      final response = await http.Response.fromStream(streamed);
      Map<String, dynamic> decoded = {};
      if (response.body.isNotEmpty) {
        final raw = jsonDecode(response.body);
        if (raw is Map) decoded = Map<String, dynamic>.from(raw);
      }
      if (response.statusCode >= 400) {
        return CloudReply(error: decoded['error'] as String? ?? 'No se pudo completar.');
      }
      return CloudReply(data: decoded);
    } catch (_) {
      return const CloudReply(error: 'No hay conexión con el servidor.');
    }
  }
}
