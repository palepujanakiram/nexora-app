import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../error/exceptions.dart';

/// Calls the deployed proxy/cloudflare-worker `/signals` route, which adds
/// the vendor's x-api-key server-side. This client never sends or holds that
/// key, on any platform.
class EpsSignalsApi {
  EpsSignalsApi(this._http, {required this.proxyBaseUrl, this.timeout = const Duration(seconds: 15)});

  final http.Client _http;

  /// The worker's base URL, e.g. `https://nexora-cors-proxy.<you>.workers.dev`.
  /// Empty when the Feed isn't configured yet.
  final String proxyBaseUrl;
  final Duration timeout;

  Future<Map<String, dynamic>> fetchSignals({
    required List<String> symbols,
    required List<String> timeframes,
    required int history,
  }) async {
    final base = proxyBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) {
      throw EpsSignalsException('The signals feed isn\'t configured yet.');
    }
    final uri = Uri.parse('$base/signals').replace(queryParameters: {
      'symbols': symbols.join(','),
      'tfs': timeframes.join(','),
      'history': '$history',
    });

    http.Response res;
    try {
      res = await _http.get(uri).timeout(timeout);
    } on TimeoutException {
      throw EpsSignalsException('The signals feed took too long to answer.');
    } catch (_) {
      throw EpsSignalsException('Couldn\'t reach the signals feed.');
    }

    final Object? decoded;
    try {
      decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      throw EpsSignalsException('The signals feed returned an unexpected response.');
    }
    if (res.statusCode != 200) {
      final message = decoded is Map ? decoded['message'] as String? : null;
      throw EpsSignalsException(message ?? 'The signals feed returned HTTP ${res.statusCode}.');
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
