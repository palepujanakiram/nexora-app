import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/datasources/remote/broker_api.dart';

void main() {
  const target = 'https://api.kite.trade/instruments/BFO';

  test('no proxy leaves the URL unchanged', () {
    expect(BrokerHttp.proxied('', target), target);
  });

  test('proxy with or without trailing slash produces the same URL', () {
    const expected = 'https://p.workers.dev/https://api.kite.trade/instruments/BFO';
    expect(BrokerHttp.proxied('https://p.workers.dev/', target), expected);
    expect(BrokerHttp.proxied('https://p.workers.dev', target), expected);
    expect(BrokerHttp.proxied('  https://p.workers.dev ', target), expected);
  });
}
