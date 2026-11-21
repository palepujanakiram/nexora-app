import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/datasources/remote/eps_signals_api.dart';
import 'package:nexora_app/common/data/repositories/eps_signals_repository_impl.dart';

void main() {
  test('fetches with the given symbols/timeframes/history and maps the JSON into an EpsFeed', () async {
    http.Request? seen;
    final api = EpsSignalsApi(
      MockClient((req) async {
        seen = req;
        return http.Response(
          '{"symbols":[{"symbol":"SENSEX","intervals":[{"timeframe":"1H","history":[]}]}]}',
          200,
        );
      }),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
    );
    final repo = EpsSignalsRepositoryImpl(api);

    final feed = await repo.fetchSignals(symbols: const ['SENSEX'], timeframes: const ['1H'], history: 1);

    expect(feed.symbols.single.symbol, 'SENSEX');
    expect(seen!.url.queryParameters, {'symbols': 'SENSEX', 'tfs': '1H', 'history': '1'});
  });

  test('defaults to both symbols, the measured-good timeframes and a history of 5', () async {
    http.Request? seen;
    final api = EpsSignalsApi(
      MockClient((req) async {
        seen = req;
        return http.Response('{"symbols":[]}', 200);
      }),
      proxyBaseUrl: 'https://proxy.example.workers.dev',
    );
    await EpsSignalsRepositoryImpl(api).fetchSignals();
    expect(seen!.url.queryParameters, {'symbols': 'NIFTY,SENSEX', 'tfs': '15m,30m,1H', 'history': '5'});
  });
}
