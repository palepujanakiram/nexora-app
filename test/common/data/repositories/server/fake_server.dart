import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/datasources/remote/nexora_server_api.dart';

/// An in-memory nexora-backend: routes are `'METHOD /path'` → JSON reply.
class FakeServer {
  FakeServer(this.routes);

  final Map<String, Object? Function(http.Request req)> routes;
  final requests = <http.Request>[];

  late final client = MockClient((req) async {
    requests.add(req);
    final query = req.url.hasQuery ? '?${req.url.query}' : '';
    final handler = routes['${req.method} ${req.url.path}$query'] ?? routes['${req.method} ${req.url.path}'];
    if (handler == null) {
      return http.Response(jsonEncode({'error': {'code': 'not_found', 'message': 'No such endpoint.'}}), 404);
    }
    final reply = handler(req);
    if (reply is http.Response) return reply;
    return http.Response(jsonEncode(reply), 200, headers: {'content-type': 'application/json'});
  });

  NexoraServerApi api() => NexoraServerApi(client, baseUrl: 'https://srv.test', token: 'tok');

  /// The JSON body of the last request to [route].
  Map<String, dynamic> bodyOf(String route) {
    final req = requests.lastWhere((r) => '${r.method} ${r.url.path}' == route);
    return jsonDecode(req.body) as Map<String, dynamic>;
  }
}

Map<String, Object?> accountJson({
  String id = 'acc1',
  String broker = 'upstox',
  bool loggedIn = false,
  bool paperMode = true,
  int lots = 1,
  String? issuedAt,
}) =>
    {
      'id': id,
      'broker': broker,
      'brokerLabel': 'Upstox',
      'label': 'Family',
      'apiKeyMasked': 'upke••••34',
      'redirectUri': 'https://127.0.0.1/',
      'enabled': true,
      'lots': lots,
      'product': 'intraday',
      'paperMode': paperMode,
      'loggedIn': loggedIn,
      // Issued now by default, so the session counts as today's whenever the tests run.
      'tokenIssuedAt': loggedIn ? issuedAt ?? DateTime.now().toUtc().toIso8601String() : null,
      'login': {'kind': 'redirect', 'url': 'https://login.example/$id', 'codeParam': 'code', 'redirectUri': 'https://127.0.0.1/'},
    };

Map<String, Object?> resultJson({String accountId = 'acc1', String? error, String? errorCode}) => {
      'id': 'e1',
      'accountId': accountId,
      'accountLabel': 'Family',
      'broker': 'Upstox',
      'signalText': 'BUY NIFTY 30 OCT 24000 PE AT 100',
      'paper': true,
      'time': '2026-10-27T04:00:00.000Z',
      'symbol': 'NIFTY 30 OCT 2026 24000 PE',
      'quantity': null,
      'entryPrice': 100,
      'orders': error == null
          ? [
              {'kind': 'ENTRY (paper)', 'id': 'PAPER-1'},
            ]
          : [],
      'error': error,
      'errorCode': errorCode,
      'success': error == null,
    };
