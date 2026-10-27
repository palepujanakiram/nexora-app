import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../error/exceptions.dart';

/// JSON client for a nexora-backend server. See the server's docs/api.md.
class NexoraServerApi {
  NexoraServerApi(this._http, {required this.baseUrl, this.token, this.timeout = const Duration(seconds: 30)});

  final http.Client _http;
  final String baseUrl;
  final String? token;
  final Duration timeout;

  /// Normalises what the user typed: trims it, drops trailing slashes and
  /// insists on https (plain http only for a server on this machine or LAN).
  static String normalizeUrl(String input) {
    final url = input.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ServerApiException('Enter the server address, e.g. https://your-app.fly.dev');
    }
    final local = uri.host == 'localhost' || uri.host == '10.0.2.2' || RegExp(r'^(127|192\.168|10)\.').hasMatch(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      throw ServerApiException('Use an https:// address for the server.');
    }
    return url;
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(String path, [Map<String, Object?>? body]) => _send('POST', path, body);

  Future<Map<String, dynamic>> patch(String path, Map<String, Object?> body) => _send('PATCH', path, body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, Object?>? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      throw ServerApiException('The server took too long to answer. Check your connection and try again.');
    } catch (_) {
      throw ServerApiException('Couldn\'t reach the server at $baseUrl. Check the address and your connection.');
    }

    final Object? decoded;
    try {
      decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      throw ServerApiException('That address answered, but it isn\'t a nexora-backend server (HTTP ${res.statusCode}).',
          statusCode: res.statusCode);
    }
    final json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (res.statusCode >= 400) {
      final error = json['error'];
      final message = error is Map ? error['message'] as String? : null;
      throw ServerApiException(
        message ?? 'The server returned HTTP ${res.statusCode}.',
        statusCode: res.statusCode,
        code: error is Map ? error['code'] as String? : null,
      );
    }
    return json;
  }
}
