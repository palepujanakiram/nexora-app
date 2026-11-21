import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/datasources/remote/eps_signals_api.dart';
import 'package:nexora_app/common/error/exceptions.dart';

void main() {
  test('refuses to call out when no proxy URL is configured', () async {
    final api = EpsSignalsApi(MockClient((_) async => http.Response('{}', 200)), proxyBaseUrl: '');
    await expectLater(
      api.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 5),
      throwsA(isA<EpsSignalsException>().having((e) => e.message, 'message', contains('isn\'t configured'))),
    );
  });

  test('builds the /signals URL with the requested symbols, timeframes and history', () async {
    http.Request? seen;
    final api = EpsSignalsApi(
      MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'symbols': []}), 200);
      }),
      proxyBaseUrl: 'https://proxy.example.workers.dev/',
    );
    final json = await api.fetchSignals(symbols: const ['NIFTY', 'SENSEX'], timeframes: const ['15m', '30m'], history: 20);
    expect(json, {'symbols': []});
    expect(seen!.url.toString(), 'https://proxy.example.workers.dev/signals?symbols=NIFTY%2CSENSEX&tfs=15m%2C30m&history=20');
  });

  test('turns a non-200 response into an EpsSignalsException using its message', () async {
    final api = EpsSignalsApi(
      MockClient((_) async => http.Response(jsonEncode({'status': 'error', 'message': 'EPS_API_KEY is not configured.'}), 500)),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
    );
    await expectLater(
      api.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 5),
      throwsA(isA<EpsSignalsException>().having((e) => e.message, 'message', 'EPS_API_KEY is not configured.')),
    );
  });

  test('falls back to a generic message when the error body has none', () async {
    final api = EpsSignalsApi(
      MockClient((_) async => http.Response(jsonEncode({'status': 'error'}), 502)),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
    );
    await expectLater(
      api.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 5),
      throwsA(isA<EpsSignalsException>().having((e) => e.message, 'message', 'The signals feed returned HTTP 502.')),
    );
  });

  test('an unparseable body is reported as an unexpected response', () async {
    final api = EpsSignalsApi(
      MockClient((_) async => http.Response('not json', 200)),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
    );
    await expectLater(
      api.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 5),
      throwsA(isA<EpsSignalsException>().having((e) => e.message, 'message', contains('unexpected response'))),
    );
  });

  test('network failures are reported as EpsSignalsException', () async {
    final failing = EpsSignalsApi(
      MockClient((_) async => throw http.ClientException('boom')),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
    );
    await expectLater(
      failing.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 5),
      throwsA(isA<EpsSignalsException>().having((e) => e.message, 'message', contains('Couldn\'t reach'))),
    );
  });

  test('a slow proxy times out with its own message', () async {
    final slow = EpsSignalsApi(
      MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      slow.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 5),
      throwsA(isA<EpsSignalsException>().having((e) => e.message, 'message', contains('took too long'))),
    );
  });

  test('an empty body on success decodes as an empty map', () async {
    final api = EpsSignalsApi(
      MockClient((_) async => http.Response('', 200)),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
    );
    expect(await api.fetchSignals(symbols: const ['NIFTY'], timeframes: const ['30m'], history: 5), isEmpty);
  });
}
