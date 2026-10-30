import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../error/exceptions.dart';

/// The signed-in session as an API client sees it: the current access token,
/// and a way to get a new one when the server rejects it.
abstract interface class ServerAuth {
  String get accessToken;

  /// Called after the server rejected [rejected] (HTTP 401). Returns a fresh
  /// access token, or null when the session is over and the user must sign in.
  Future<String?> renew(String rejected);
}

/// JSON client for a nexora-backend server. See the server's docs/api.md.
class NexoraServerApi {
  NexoraServerApi(
    this._http, {
    required this.baseUrl,
    this.token,
    this.auth,
    this.timeout = const Duration(seconds: 30),
  });

  final http.Client _http;
  final String baseUrl;

  /// A fixed bearer token. Ignored when [auth] is set.
  final String? token;

  /// The session that signs requests and renews its access token on a 401.
  final ServerAuth? auth;
  final Duration timeout;

  /// Normalises what the user typed: trims it, drops trailing slashes and
  /// insists on https (plain http only for a server on this machine or LAN).
  static String normalizeUrl(String input) {
    final url = input.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ServerApiException('Enter the server address, e.g. https://your-app.fly.dev');
    }
    final local =
        uri.host == 'localhost' || uri.host == '10.0.2.2' || RegExp(r'^(127|192\.168|10)\.').hasMatch(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      throw ServerApiException('Use an https:// address for the server.');
    }
    return url;
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  /// [idempotencyKey] is required by the order endpoints: the same key and
  /// body sent again returns the first answer instead of placing twice.
  Future<Map<String, dynamic>> post(String path, [Map<String, Object?>? body, String? idempotencyKey]) =>
      _send('POST', path, body, idempotencyKey);

  Future<Map<String, dynamic>> patch(String path, Map<String, Object?> body) => _send('PATCH', path, body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
    String? idempotencyKey,
  ]) async {
    final auth = this.auth;
    var bearer = auth?.accessToken ?? token;
    var res = await _attempt(method, path, body, idempotencyKey, bearer);
    if (res.statusCode == 401 && auth != null && bearer != null) {
      // The access token lives minutes; renew it once and try again. Safe for
      // writes: the server refused the first attempt before doing anything.
      bearer = await auth.renew(bearer);
      if (bearer != null) res = await _attempt(method, path, body, idempotencyKey, bearer);
    }
    return _decode(res);
  }

  Future<http.Response> _attempt(
    String method,
    String path,
    Map<String, Object?>? body,
    String? idempotencyKey,
    String? bearer,
  ) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
        if (body != null) 'Content-Type': 'application/json',
        'Idempotency-Key': ?idempotencyKey,
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      return await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } on TimeoutException {
      throw ServerApiException('The server took too long to answer. Check your connection and try again.');
    } catch (_) {
      throw ServerApiException('Couldn\'t reach the server at $baseUrl. Check the address and your connection.');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    final Object? decoded;
    try {
      decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      throw ServerApiException(
        'That address answered, but it isn\'t a nexora-backend server (HTTP ${res.statusCode}).',
        statusCode: res.statusCode,
      );
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
