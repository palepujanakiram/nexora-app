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
  Map<String, dynamic> bodyOf(String route) => jsonDecode(last(route).body) as Map<String, dynamic>;

  /// The last request to [route].
  http.Request last(String route) => requests.lastWhere((r) => '${r.method} ${r.url.path}' == route);
}

/// An account as `GET /broker-accounts` describes it.
Map<String, Object?> accountJson({
  String id = 'acc1',
  String broker = 'upstox',
  String label = 'Family',
  String mode = 'paper',
  String state = 'none',
}) =>
    {
      'id': id,
      'broker': broker,
      'label': label,
      'mode': mode,
      'apiKeyMasked': 'up••••34',
      'token': {'state': state, 'expiresAt': null, 'lastAuthAt': null, 'message': null},
      'createdAt': '2026-10-30T04:00:00.000Z',
    };

/// One leg of a `207` order reply.
Map<String, Object?> legJson({
  String accountId = 'acc1',
  String status = 'OPEN',
  String mode = 'live',
  String broker = 'upstox',
  int quantity = 75,
  String? brokerOrderId = 'B1',
  Map<String, Object?>? error,
}) =>
    {
      'legId': 'leg_$accountId',
      'accountId': accountId,
      'broker': broker,
      'mode': mode,
      'status': status,
      'brokerOrderId': brokerOrderId,
      'quantity': quantity,
      'filledQty': 0,
      'avgPrice': null,
      'orderType': 'LIMIT',
      'price': '100.00',
      'triggerPrice': null,
      'error': ?error,
      'reconcileScheduled': true,
    };

/// An order as `GET /orders` lists it.
Map<String, Object?> orderJson({
  String id = 'po_1',
  String kind = 'ENTRY',
  String createdAt = '2026-10-30T04:00:00.000Z',
  List<Map<String, Object?>>? legs,
}) =>
    {
      'parentOrderId': id,
      'kind': kind,
      'exitOf': null,
      'status': 'IN_PROGRESS',
      'instrumentId': 'NFO:PE:NIFTY:2026-10-30:2400000',
      'side': 'BUY',
      'quantity': 75,
      'orderType': 'LIMIT',
      'product': 'INTRADAY',
      'price': '100.00',
      'triggerPrice': null,
      'referencePrice': '100.00',
      'createdAt': createdAt,
      'updatedAt': createdAt,
      'legs': legs ?? [legJson()],
    };
