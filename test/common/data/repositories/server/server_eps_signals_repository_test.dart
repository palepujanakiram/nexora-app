import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexora_app/common/data/repositories/server/server_eps_signals_repository.dart';
import 'package:nexora_app/common/error/exceptions.dart';

import 'fake_server.dart';

void main() {
  test('sends symbols/tfs/history as a query string and maps the JSON into an EpsFeed', () async {
    final fake = FakeServer({
      'GET /signals/feed?symbols=NIFTY&tfs=30m&history=1': (_) => {
            'symbols': [
              {'symbol': 'NIFTY', 'price': 25800.6},
            ],
          },
    });
    final repo = ServerEpsSignalsRepository(fake.api());

    final feed = await repo.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 1);

    expect(feed.symbols.single.symbol, 'NIFTY');
    expect(feed.symbols.single.price, 25800.6);
  });

  test('defaults to both symbols, the measured-good timeframes and a history of 5', () async {
    final fake = FakeServer({
      'GET /signals/feed?symbols=NIFTY%2CSENSEX&tfs=15m%2C30m%2C1H&history=5': (_) => {'symbols': []},
    });
    final feed = await ServerEpsSignalsRepository(fake.api()).fetchSignals();
    expect(feed.symbols, isEmpty);
  });

  test('a 503 from the server (EPS_API_KEY not configured) surfaces as a ServerApiException', () async {
    final fake = FakeServer({
      'GET /signals/feed?symbols=NIFTY&tfs=30m&history=1': (_) => http.Response(
            jsonEncode({
              'error': {'code': 'eps_not_configured', 'message': 'The signals feed is not configured on this server.'},
            }),
            503,
          ),
    });
    await expectLater(
      ServerEpsSignalsRepository(fake.api()).fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 1),
      throwsA(isA<ServerApiException>().having((e) => e.message, 'message', 'The signals feed is not configured on this server.')),
    );
  });
}
