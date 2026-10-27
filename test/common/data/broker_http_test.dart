import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/datasources/remote/broker_api.dart';
import 'package:nexora_app/common/error/exceptions.dart';

class _Http with BrokerHttp {
  _Http(this.corsProxy);
  @override
  final String corsProxy;
}

void main() {
  const target = 'https://api.kite.trade/instruments/BFO';

  group('proxied', () {
    test('no proxy leaves the URL unchanged', () {
      expect(BrokerHttp.proxied('', target), target);
      expect(BrokerHttp.proxied('   ', target), target);
    });

    test('proxy with or without trailing slash produces the same URL', () {
      const expected = 'https://p.workers.dev/https://api.kite.trade/instruments/BFO';
      expect(BrokerHttp.proxied('https://p.workers.dev/', target), expected);
      expect(BrokerHttp.proxied('https://p.workers.dev', target), expected);
      expect(BrokerHttp.proxied('  https://p.workers.dev ', target), expected);
    });
  });

  group('url', () {
    test('parses the target directly without a proxy', () {
      final uri = _Http('').url('https://api.kite.trade/quote/ltp?i=NFO%3AX');
      expect(uri.toString(), 'https://api.kite.trade/quote/ltp?i=NFO%3AX');
      expect(uri.host, 'api.kite.trade');
      expect(uri.queryParameters['i'], 'NFO:X');
    });

    test('prefixes the proxy and keeps the target query', () {
      final uri = _Http('https://p.dev/').url('https://api.kite.trade/quote/ltp?i=NFO%3AX');
      expect(uri.host, 'p.dev');
      expect(uri.toString(), 'https://p.dev/https://api.kite.trade/quote/ltp?i=NFO%3AX');
      expect(uri.queryParameters['i'], 'NFO:X');
    });
  });

  group('extractParam', () {
    test('returns a bare code trimmed', () {
      expect(BrokerHttp.extractParam('  abc123 ', 'code'), 'abc123');
    });

    test('extracts the parameter from a full redirect URL', () {
      expect(
        BrokerHttp.extractParam('https://example.com/cb?status=success&request_token=RT42&action=login', 'request_token'),
        'RT42',
      );
      expect(BrokerHttp.extractParam(' https://example.com/cb?code=XyZ ', 'code'), 'XyZ');
    });

    test('throws when a URL lacks the parameter', () {
      expect(
        () => BrokerHttp.extractParam('https://example.com/cb?state=1', 'code'),
        throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', 'No "code" found in the pasted URL.')),
      );
    });

    test('throws when the parameter is present but empty', () {
      expect(
        () => BrokerHttp.extractParam('https://example.com/cb?request_token=', 'request_token'),
        throwsA(isA<BrokerApiException>()
            .having((e) => e.message, 'message', 'No "request_token" found in the pasted URL.')),
      );
    });

    test('throws for a query-only string without the parameter', () {
      expect(() => BrokerHttp.extractParam('?foo=bar', 'code'), throwsA(isA<BrokerApiException>()));
    });

    test('extracts from a query-only string', () {
      expect(BrokerHttp.extractParam('?code=abc', 'code'), 'abc');
    });

    test('scheme-only text without the param throws', () {
      expect(() => BrokerHttp.extractParam('app://callback', 'code'), throwsA(isA<BrokerApiException>()));
    });
  });
}
