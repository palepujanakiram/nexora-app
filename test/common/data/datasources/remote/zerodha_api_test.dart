import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/datasources/remote/zerodha_api.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';
import 'package:nexora_app/common/error/exceptions.dart';

const _account = BrokerAccount(
  id: 'z1',
  broker: BrokerType.zerodha,
  label: 'Kite',
  apiKey: 'my key',
  apiSecret: 'sec',
  accessToken: 'acc',
);

TradeSignal _signal({
  String underlying = 'NIFTY',
  double strike = 24000,
  OptionType type = OptionType.call,
  TradeAction action = TradeAction.buy,
  DateTime? expiry,
}) =>
    TradeSignal(
      action: action,
      underlying: underlying,
      expiry: expiry ?? DateTime(2024, 10, 31),
      strike: strike,
      optionType: type,
      entryLow: 400,
      entryHigh: 420,
      stopLoss: 300,
      targets: const [540],
      raw: 'raw',
    );

const _inst = ResolvedInstrument(symbol: 'NIFTY24O3124000CE', exchange: 'NFO', lotSize: 25);

http.Response _ok(Object data) => http.Response(jsonEncode({'status': 'success', 'data': data}), 200);

Matcher _brokerError(String message) =>
    throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', message));

/// Records every request and answers with [handler].
MockClient _client(List<http.Request> log, Future<http.Response> Function(http.Request r) handler) =>
    MockClient((r) {
      log.add(r);
      return handler(r);
    });

const _nfoCsv = 'instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,'
    'instrument_type,segment,exchange\n'
    '1,1,NIFTY24O3124000PE,"NIFTY",0,2024-10-31,24000,0.05,25,PE,NFO-OPT,NFO\n'
    '2,2,NIFTY24N0724000CE,"NIFTY",0,2024-11-07,24000,0.05,25,CE,NFO-OPT,NFO\n'
    '3,3,NIFTY24O3124050CE,"NIFTY",0,2024-10-31,24050,0.05,25,CE,NFO-OPT,NFO\n'
    '4,4,ODD24O3124000CE,"ODD, INC",0,2024-10-31,24000,0.05,25,CE,NFO-OPT,NFO\n'
    '\n'
    '5,5,NIFTY24O3124000CE,"NIFTY",0,2024-10-31,24000.0,0.1,75,CE,NFO-OPT,NFO,extra\n';

void main() {
  group('loginUrl', () {
    test('builds the Kite Connect login URL with an encoded api key', () {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('', 500)), '');
      expect(api.loginUrl(), 'https://kite.zerodha.com/connect/login?v=3&api_key=my%20key');
    });

    test('is never proxied', () {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('', 500)), 'https://p.dev/');
      expect(api.loginUrl(), startsWith('https://kite.zerodha.com/'));
    });
  });

  group('exchangeToken', () {
    test('posts api_key, request_token and the sha256 checksum', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => _ok({'access_token': 'NEWTOKEN'})), '');
      final token = await api.exchangeToken('https://app.example/cb?action=login&status=success&request_token=RT1');

      expect(token, 'NEWTOKEN');
      expect(log, hasLength(1));
      final r = log.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://api.kite.trade/session/token');
      expect(r.headers['X-Kite-Version'], '3');
      expect(r.headers.containsKey('Authorization'), isFalse);
      expect(r.headers['content-type'], startsWith('application/x-www-form-urlencoded'));
      expect(r.bodyFields, {
        'api_key': 'my key',
        'request_token': 'RT1',
        'checksum': sha256.convert(utf8.encode('my keyRT1sec')).toString(),
      });
      expect(r.bodyFields['checksum'], hasLength(64));
    });

    test('accepts a bare request token and goes through the proxy', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => _ok({'access_token': 'T'})), 'https://p.dev');
      expect(await api.exchangeToken('  RT2 '), 'T');
      expect(log.single.url.toString(), 'https://p.dev/https://api.kite.trade/session/token');
      expect(log.single.bodyFields['request_token'], 'RT2');
    });

    test('rejects a pasted URL without request_token before calling Kite', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => _ok({})), '');
      await expectLater(
        api.exchangeToken('https://app.example/cb?status=cancelled'),
        _brokerError('No "request_token" found in the pasted URL.'),
      );
      expect(log, isEmpty);
    });

    test('surfaces the Kite error message', () async {
      final api = ZerodhaApi(
        _account,
        MockClient((_) async => http.Response(
            jsonEncode({'status': 'error', 'message': 'Token is invalid or has expired.', 'error_type': 'TokenException'}),
            403)),
        '',
      );
      await expectLater(api.exchangeToken('RT'), _brokerError('Kite: Token is invalid or has expired.'));
    });

    test('falls back to the HTTP status when the error has no message', () async {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('{"status":"error"}', 500)), '');
      await expectLater(api.exchangeToken('RT'), _brokerError('Kite: HTTP 500'));
    });

    test('treats a 200 without status success as an error', () async {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('{"status":"pending"}', 200)), '');
      await expectLater(api.exchangeToken('RT'), _brokerError('Kite: HTTP 200'));
    });

    test('reports non-JSON responses with the HTTP status', () async {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('<html>Bad gateway</html>', 502)), '');
      await expectLater(api.exchangeToken('RT'), _brokerError('Kite returned HTTP 502.'));
    });

    test('reports JSON that is not an object as malformed', () async {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('[1,2]', 200)), '');
      await expectLater(api.exchangeToken('RT'), _brokerError('Kite returned HTTP 200.'));
    });
  });

  // The instrument cache is static and keyed by exchange + day, so these tests
  // run in order: a failed download is not cached, the first successful one is.
  group('resolve', () {
    test('fails with a session hint when the instrument download is rejected', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => http.Response('Forbidden', 403)), '');
      await expectLater(
        api.resolve(_signal()),
        _brokerError('Kite instruments download failed (403). Is the session valid?'),
      );
      expect(log.single.method, 'GET');
      expect(log.single.url.toString(), 'https://api.kite.trade/instruments/NFO');
      expect(log.single.headers['X-Kite-Version'], '3');
      expect(log.single.headers['Authorization'], 'token my key:acc');
    });

    test('downloads the instrument CSV through the proxy and finds the contract', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => http.Response(_nfoCsv, 200)), 'https://p.dev/');
      final inst = await api.resolve(_signal());

      expect(log.single.url.toString(), 'https://p.dev/https://api.kite.trade/instruments/NFO');
      expect(inst.symbol, 'NIFTY24O3124000CE');
      expect(inst.exchange, 'NFO');
      expect(inst.lotSize, 75);
      expect(inst.tickSize, 0.1);
      expect(inst.instrumentKey, isNull);
    });

    test('reuses the cached instruments for the same exchange and day', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => http.Response('', 500)), '');
      final put = await api.resolve(_signal(type: OptionType.put));
      expect(put.symbol, 'NIFTY24O3124000PE');
      expect(put.lotSize, 25);
      expect(put.tickSize, 0.05);
      final later = await api.resolve(_signal(expiry: DateTime(2024, 11, 7)));
      expect(later.symbol, 'NIFTY24N0724000CE');
      expect(log, isEmpty);
    });

    test('quoted commas do not shift columns', () async {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('', 500)), '');
      final odd = await api.resolve(_signal(underlying: 'ODD, INC'));
      expect(odd.symbol, 'ODD24O3124000CE');
    });

    test('throws when no contract matches', () async {
      final api = ZerodhaApi(_account, MockClient((_) async => http.Response('', 500)), '');
      await expectLater(
        api.resolve(_signal(strike: 25000)),
        _brokerError('No Kite contract found for NIFTY 31 OCT 2024 25000 CE on NFO.'),
      );
    });

    test('defaults exchange and tick size when the CSV lacks those columns', () async {
      final log = <http.Request>[];
      const csv = 'tradingsymbol,name,expiry,strike,lot_size,instrument_type\n'
          'SENSEX24O3173100PE,SENSEX,2024-10-31,73100,20,PE\n';
      final api = ZerodhaApi(_account, _client(log, (_) async => http.Response(csv, 200)), '');
      final inst = await api.resolve(_signal(underlying: 'SENSEX', strike: 73100, type: OptionType.put));

      expect(log.single.url.toString(), 'https://api.kite.trade/instruments/BFO');
      expect(inst.symbol, 'SENSEX24O3173100PE');
      expect(inst.exchange, 'BFO');
      expect(inst.lotSize, 20);
      expect(inst.tickSize, 0.05);
    });
  });

  group('placeTrade', () {
    TradePlan plan({
      TradeAction action = TradeAction.buy,
      double? sl = 300,
      double? tgt = 540,
      ProductType product = ProductType.carryForward,
    }) =>
        TradePlan(
          signal: _signal(action: action),
          quantity: 50,
          entryPrice: 420,
          product: product,
          stopLoss: sl,
          target: tgt,
        );

    test('entry-only plan places a single intraday LIMIT order', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => _ok({'order_id': '241031000001'})), '');
      final orders = await api.placeTrade(_inst, plan(sl: null, tgt: null, product: ProductType.intraday));

      expect(log, hasLength(1));
      final r = log.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://api.kite.trade/orders/regular');
      expect(r.headers['Authorization'], 'token my key:acc');
      expect(r.headers['X-Kite-Version'], '3');
      expect(r.bodyFields, {
        'tradingsymbol': 'NIFTY24O3124000CE',
        'exchange': 'NFO',
        'transaction_type': 'BUY',
        'order_type': 'LIMIT',
        'quantity': '50',
        'price': '420.00',
        'product': 'MIS',
        'validity': 'DAY',
        'tag': 'signal',
      });
      expect(orders.map((o) => (o.kind, o.id)), [('ENTRY', '241031000001')]);
    });

    test('a stop loss without a target places no GTT', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(_account, _client(log, (_) async => _ok({'order_id': 7})), '');
      final orders = await api.placeTrade(_inst, plan(tgt: null));
      expect(log, hasLength(1));
      expect(log.single.bodyFields['product'], 'NRML');
      expect(orders.single.id, '7');
    });

    test('buy plan places entry then a two-leg GTT with ascending legs', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(
        _account,
        _client(log, (r) async {
          if (r.url.path.endsWith('/orders/regular')) return _ok({'order_id': 'E1'});
          if (r.url.path.endsWith('/quote/ltp')) {
            return _ok({
              'NFO:NIFTY24O3124000CE': {'instrument_token': 1, 'last_price': 433.5},
            });
          }
          return _ok({'trigger_id': 99});
        }),
        'https://p.dev/',
      );
      final orders = await api.placeTrade(_inst, plan());

      expect(log.map((r) => r.method), ['POST', 'GET', 'POST']);
      expect(log[0].url.toString(), 'https://p.dev/https://api.kite.trade/orders/regular');
      expect(log[0].bodyFields['product'], 'NRML');

      final ltp = log[1];
      expect(ltp.url.toString(), 'https://p.dev/https://api.kite.trade/quote/ltp?i=NFO%3ANIFTY24O3124000CE');
      expect(ltp.url.queryParameters['i'], 'NFO:NIFTY24O3124000CE');
      expect(ltp.headers['Authorization'], 'token my key:acc');

      final gtt = log[2];
      expect(gtt.url.toString(), 'https://p.dev/https://api.kite.trade/gtt/triggers');
      expect(gtt.headers['Authorization'], 'token my key:acc');
      expect(gtt.bodyFields['type'], 'two-leg');
      expect(jsonDecode(gtt.bodyFields['condition']!), {
        'exchange': 'NFO',
        'tradingsymbol': 'NIFTY24O3124000CE',
        'trigger_values': [300, 540],
        'last_price': 433.5,
      });
      final legs = jsonDecode(gtt.bodyFields['orders']!) as List;
      expect(legs, [
        {
          'exchange': 'NFO',
          'tradingsymbol': 'NIFTY24O3124000CE',
          'transaction_type': 'SELL',
          'quantity': 50,
          'order_type': 'LIMIT',
          'product': 'NRML',
          'price': 285, // 5% below the 300 stop loss
        },
        {
          'exchange': 'NFO',
          'tradingsymbol': 'NIFTY24O3124000CE',
          'transaction_type': 'SELL',
          'quantity': 50,
          'order_type': 'LIMIT',
          'product': 'NRML',
          'price': 540,
        },
      ]);

      expect(orders.map((o) => (o.kind, o.id)), [
        ('ENTRY', 'E1'),
        ('GTT OCO (SL 300.0 / TGT 540.0)', '99'),
      ]);
    });

    test('sell plan buys back with the stop loss leg above the target and a tick-rounded buffer', () async {
      final log = <http.Request>[];
      const inst = ResolvedInstrument(symbol: 'S', exchange: 'BFO', lotSize: 20, tickSize: 0.5);
      final api = ZerodhaApi(
        _account,
        _client(log, (r) async {
          if (r.url.path.endsWith('/orders/regular')) return _ok({'order_id': 'E2'});
          if (r.url.path.endsWith('/quote/ltp')) {
            return _ok({
              'BFO:S': {'last_price': 410},
            });
          }
          return _ok({'trigger_id': 'G2'});
        }),
        '',
      );
      final orders = await api.placeTrade(inst, plan(action: TradeAction.sell, sl: 501, tgt: 300, product: ProductType.intraday));

      expect(log[0].bodyFields['transaction_type'], 'SELL');
      expect(log[0].bodyFields['product'], 'MIS');
      final gtt = log[2];
      final condition = jsonDecode(gtt.bodyFields['condition']!) as Map;
      expect(condition['trigger_values'], [300, 501]);
      expect(condition['last_price'], 410);
      final legs = (jsonDecode(gtt.bodyFields['orders']!) as List).cast<Map>();
      expect(legs.map((l) => l['transaction_type']), ['BUY', 'BUY']);
      expect(legs.map((l) => l['product']), ['MIS', 'MIS']);
      // 501 * 1.05 = 526.05, rounded to the 0.5 tick.
      expect(legs.map((l) => l['price']), [300, 526.0]);
      expect(orders.last.kind, 'GTT OCO (SL 501.0 / TGT 300.0)');
      expect(orders.last.id, 'G2');
    });

    test('uses the entry price as last_price when the LTP lookup fails', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(
        _account,
        _client(log, (r) async {
          if (r.url.path.endsWith('/orders/regular')) return _ok({'order_id': 'E3'});
          if (r.url.path.endsWith('/quote/ltp')) return http.Response('{"status":"error","message":"nope"}', 500);
          return _ok({'trigger_id': 3});
        }),
        '',
      );
      final orders = await api.placeTrade(_inst, plan());
      expect(log, hasLength(3));
      expect((jsonDecode(log[2].bodyFields['condition']!) as Map)['last_price'], 420);
      expect(orders, hasLength(2));
    });

    test('uses the entry price when the LTP response lacks the instrument', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(
        _account,
        _client(log, (r) async {
          if (r.url.path.endsWith('/orders/regular')) return _ok({'order_id': 'E4'});
          if (r.url.path.endsWith('/quote/ltp')) return _ok({});
          return _ok({'trigger_id': 4});
        }),
        '',
      );
      await api.placeTrade(_inst, plan());
      expect((jsonDecode(log[2].bodyFields['condition']!) as Map)['last_price'], 420);
    });

    test('a rejected entry stops before any GTT is placed', () async {
      final log = <http.Request>[];
      final api = ZerodhaApi(
        _account,
        _client(log, (_) async => http.Response(
            jsonEncode({'status': 'error', 'message': 'Insufficient funds', 'error_type': 'MarginException'}), 400)),
        '',
      );
      await expectLater(api.placeTrade(_inst, plan()), _brokerError('Kite: Insufficient funds'));
      expect(log, hasLength(1));
    });

    test('a rejected GTT surfaces the Kite error', () async {
      final api = ZerodhaApi(
        _account,
        MockClient((r) async {
          if (r.url.path.endsWith('/orders/regular')) return _ok({'order_id': 'E5'});
          if (r.url.path.endsWith('/quote/ltp')) {
            return _ok({
              'NFO:NIFTY24O3124000CE': {'last_price': 420},
            });
          }
          return http.Response(jsonEncode({'status': 'error', 'message': 'Invalid trigger'}), 400);
        }),
        '',
      );
      await expectLater(api.placeTrade(_inst, plan()), _brokerError('Kite: Invalid trigger'));
    });
  });
}
