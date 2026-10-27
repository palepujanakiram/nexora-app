import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/datasources/remote/upstox_api.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';
import 'package:nexora_app/common/error/exceptions.dart';

const _account = BrokerAccount(
  id: 'u1',
  broker: BrokerType.upstox,
  label: 'Upstox',
  apiKey: 'client-id',
  apiSecret: 'client-secret',
  redirectUri: 'https://app.example/callback',
  accessToken: 'bearer-tok',
);

TradeSignal _signal({
  String underlying = 'NIFTY',
  double strike = 24000,
  OptionType type = OptionType.call,
  TradeAction action = TradeAction.buy,
}) =>
    TradeSignal(
      action: action,
      underlying: underlying,
      expiry: DateTime(2024, 10, 31),
      strike: strike,
      optionType: type,
      entryLow: 400,
      entryHigh: 420,
      stopLoss: 300,
      targets: const [540],
      raw: 'raw',
    );

const _inst = ResolvedInstrument(
  symbol: 'NIFTY 24000 CE 31 OCT 24',
  exchange: 'NFO',
  lotSize: 25,
  instrumentKey: 'NSE_FO|43885',
);

http.Response _ok(Object? data) => http.Response(jsonEncode({'status': 'success', 'data': data}), 200);

http.Response _err(int status, String message) => http.Response(
      jsonEncode({
        'status': 'error',
        'errors': [
          {'errorCode': 'UDAPI100', 'message': message},
        ],
      }),
      status,
    );

Matcher _brokerError(String message) =>
    throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', message));

MockClient _client(List<http.Request> log, Future<http.Response> Function(http.Request r) handler) =>
    MockClient((r) {
      log.add(r);
      return handler(r);
    });

void _expectAuthJson(http.Request r) {
  expect(r.headers['Authorization'], 'Bearer bearer-tok');
  expect(r.headers['Accept'], 'application/json');
  expect(r.headers['Content-Type'], startsWith('application/json'));
}

void main() {
  test('maps index underlyings to instrument keys', () {
    expect(UpstoxApi.underlyingKeys['NIFTY'], 'NSE_INDEX|Nifty 50');
    expect(UpstoxApi.underlyingKeys['SENSEX'], 'BSE_INDEX|SENSEX');
    expect(UpstoxApi.underlyingKeys.containsKey('RELIANCE'), isFalse);
  });

  group('loginUrl', () {
    test('builds the authorization dialog URL with client id and redirect URI', () {
      final api = UpstoxApi(_account, MockClient((_) async => http.Response('', 500)), 'https://p.dev/');
      final uri = Uri.parse(api.loginUrl());
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.upstox.com');
      expect(uri.path, '/v2/login/authorization/dialog');
      expect(uri.queryParameters, {
        'response_type': 'code',
        'client_id': 'client-id',
        'redirect_uri': 'https://app.example/callback',
      });
      expect(api.loginUrl(), contains('redirect_uri=https%3A%2F%2Fapp.example%2Fcallback'));
    });
  });

  group('exchangeToken', () {
    test('posts the authorization code form and returns the access token', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(_account, _client(log, (_) async => http.Response('{"access_token":"AT"}', 200)), '');
      expect(await api.exchangeToken('https://app.example/callback?code=C0DE&state=x'), 'AT');

      final r = log.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://api.upstox.com/v2/login/authorization/token');
      expect(r.headers['Accept'], 'application/json');
      expect(r.headers.containsKey('Authorization'), isFalse);
      expect(r.headers['content-type'], startsWith('application/x-www-form-urlencoded'));
      expect(r.bodyFields, {
        'code': 'C0DE',
        'client_id': 'client-id',
        'client_secret': 'client-secret',
        'redirect_uri': 'https://app.example/callback',
        'grant_type': 'authorization_code',
      });
    });

    test('accepts a bare code and uses the proxy', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(_account, _client(log, (_) async => http.Response('{"access_token":"AT2"}', 200)), 'https://p.dev');
      expect(await api.exchangeToken(' abc '), 'AT2');
      expect(log.single.url.toString(), 'https://p.dev/https://api.upstox.com/v2/login/authorization/token');
      expect(log.single.bodyFields['code'], 'abc');
    });

    test('rejects a redirect URL without a code before calling Upstox', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(_account, _client(log, (_) async => http.Response('{}', 200)), '');
      await expectLater(api.exchangeToken('https://app.example/callback?error=denied'),
          _brokerError('No "code" found in the pasted URL.'));
      expect(log, isEmpty);
    });

    test('surfaces the first Upstox error message', () async {
      final api = UpstoxApi(_account, MockClient((_) async => _err(401, 'Invalid Auth code')), '');
      await expectLater(api.exchangeToken('c'), _brokerError('Upstox: Invalid Auth code'));
    });

    test('a 200 without a token is an error', () async {
      final api = UpstoxApi(_account, MockClient((_) async => http.Response('{}', 200)), '');
      await expectLater(api.exchangeToken('c'), _brokerError('Upstox: HTTP 200'));
    });

    test('a non-200 with a token is still an error', () async {
      final api = UpstoxApi(
          _account, MockClient((_) async => http.Response('{"access_token":"AT","errors":[]}', 400)), '');
      await expectLater(api.exchangeToken('c'), _brokerError('Upstox: HTTP 400'));
    });

    test('reports non-JSON responses with the HTTP status', () async {
      final api = UpstoxApi(_account, MockClient((_) async => http.Response('<html>', 502)), '');
      await expectLater(api.exchangeToken('c'), _brokerError('Upstox returned HTTP 502.'));
    });
  });

  group('resolve', () {
    final contracts = [
      {'instrument_type': 'PE', 'strike_price': 24000, 'trading_symbol': 'P', 'lot_size': 25, 'instrument_key': 'K1'},
      {'instrument_type': 'CE', 'strike_price': 24050.0, 'trading_symbol': 'C2', 'lot_size': 25, 'instrument_key': 'K2'},
      {
        'instrument_type': 'CE',
        'strike_price': 24000,
        'trading_symbol': 'NIFTY 24000 CE 31 OCT 24',
        'lot_size': 75.0,
        'instrument_key': 'NSE_FO|43885',
      },
    ];

    test('rejects unmapped underlyings without calling Upstox', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(_account, _client(log, (_) async => _ok([])), '');
      await expectLater(api.resolve(_signal(underlying: 'RELIANCE')),
          _brokerError('Upstox: underlying RELIANCE is not mapped yet (indices only).'));
      expect(log, isEmpty);
    });

    test('looks up the option contract by underlying key and expiry', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(_account, _client(log, (_) async => _ok(contracts)), '');
      final inst = await api.resolve(_signal());

      final r = log.single;
      expect(r.method, 'GET');
      expect(r.url.host, 'api.upstox.com');
      expect(r.url.path, '/v2/option/contract');
      expect(r.url.queryParameters, {'instrument_key': 'NSE_INDEX|Nifty 50', 'expiry_date': '2024-10-31'});
      _expectAuthJson(r);

      expect(inst.symbol, 'NIFTY 24000 CE 31 OCT 24');
      expect(inst.exchange, 'NFO');
      expect(inst.lotSize, 75);
      expect(inst.instrumentKey, 'NSE_FO|43885');
      expect(inst.tickSize, 0.05);
    });

    test('goes through the proxy for BSE indices', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(
        _account,
        _client(log, (_) async => _ok([
              {'instrument_type': 'PE', 'strike_price': 73100, 'trading_symbol': 'SX', 'lot_size': 20, 'instrument_key': 'BSE_FO|1'},
            ])),
        'https://p.dev/',
      );
      final inst = await api.resolve(_signal(underlying: 'SENSEX', strike: 73100, type: OptionType.put));
      expect(log.single.url.toString(),
          startsWith('https://p.dev/https://api.upstox.com/v2/option/contract?'));
      expect(log.single.url.queryParameters['instrument_key'], 'BSE_INDEX|SENSEX');
      expect(inst.exchange, 'BFO');
      expect(inst.instrumentKey, 'BSE_FO|1');
    });

    test('throws when no contract matches', () async {
      final api = UpstoxApi(_account, MockClient((_) async => _ok(contracts)), '');
      await expectLater(api.resolve(_signal(strike: 25000)),
          _brokerError('No Upstox contract found for NIFTY 31 OCT 2024 25000 CE.'));
    });

    test('surfaces API errors', () async {
      final api = UpstoxApi(_account, MockClient((_) async => _err(401, 'Invalid token used to access API')), '');
      await expectLater(api.resolve(_signal()), _brokerError('Upstox: Invalid token used to access API'));
    });

    test('a 200 without status success falls back to the HTTP status', () async {
      final api = UpstoxApi(_account, MockClient((_) async => http.Response('{"status":"error","errors":"x"}', 200)), '');
      await expectLater(api.resolve(_signal()), _brokerError('Upstox: HTTP 200'));
    });

    test('reports malformed responses', () async {
      final api = UpstoxApi(_account, MockClient((_) async => http.Response('not json', 500)), '');
      await expectLater(api.resolve(_signal()), _brokerError('Upstox returned HTTP 500.'));
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
          quantity: 75,
          entryPrice: 420,
          product: product,
          stopLoss: sl,
          target: tgt,
        );

    test('entry-only plan places a sliced LIMIT order on the HFT endpoint', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(
        _account,
        _client(log, (_) async => _ok({
              'order_ids': ['1001', 1002],
            })),
        'https://p.dev/',
      );
      final orders = await api.placeTrade(_inst, plan(sl: null, tgt: null, product: ProductType.intraday));

      final r = log.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://p.dev/https://api-hft.upstox.com/v3/order/place');
      _expectAuthJson(r);
      expect(jsonDecode(r.body), {
        'quantity': 75,
        'product': 'I',
        'validity': 'DAY',
        'price': 420,
        'tag': 'signal',
        'instrument_token': 'NSE_FO|43885',
        'order_type': 'LIMIT',
        'transaction_type': 'BUY',
        'disclosed_quantity': 0,
        'trigger_price': 0,
        'is_amo': false,
        'slice': true,
      });
      expect(orders.map((o) => (o.kind, o.id)), [('ENTRY', '1001'), ('ENTRY', '1002')]);
    });

    test('a plan with only a stop loss is entry-only (carry forward = D)', () async {
      final log = <http.Request>[];
      final api = UpstoxApi(_account, _client(log, (_) async => _ok({'order_ids': ['9']})), '');
      final orders = await api.placeTrade(_inst, plan(tgt: null, action: TradeAction.sell));
      expect(log.single.url.path, '/v3/order/place');
      final body = jsonDecode(log.single.body) as Map;
      expect(body['product'], 'D');
      expect(body['transaction_type'], 'SELL');
      expect(orders.single.id, '9');
    });

    test('entry-only order errors are surfaced', () async {
      final api = UpstoxApi(_account, MockClient((_) async => _err(400, 'Insufficient funds')), '');
      await expectLater(api.placeTrade(_inst, plan(sl: null, tgt: null)), _brokerError('Upstox: Insufficient funds'));
    });

    Future<(List<http.Request>, List<dynamic>)> placeGtt(
      TradePlan p, {
      double? ltp,
      ProductType? product,
    }) async {
      final log = <http.Request>[];
      final api = UpstoxApi(
        _account,
        _client(log, (r) async {
          if (r.url.path.endsWith('/market-quote/ltp')) {
            if (ltp == null) return _err(500, 'quote down');
            return _ok({
              'NSE_FO:NIFTY24O3124000CE': {'last_price': ltp, 'instrument_token': 'NSE_FO|43885'},
            });
          }
          return _ok({
            'gtt_order_ids': ['GTT-1'],
          });
        }),
        '',
      );
      final orders = await api.placeTrade(_inst, p);
      return (log, orders);
    }

    test('plan with exits places a MULTIPLE GTT after reading the LTP', () async {
      final (log, orders) = await placeGtt(plan(), ltp: 450);

      expect(log.map((r) => r.method), ['GET', 'POST']);
      final q = log[0];
      expect(q.url.host, 'api.upstox.com');
      expect(q.url.path, '/v2/market-quote/ltp');
      expect(q.url.queryParameters, {'instrument_key': 'NSE_FO|43885'});
      _expectAuthJson(q);

      final g = log[1];
      expect(g.url.toString(), 'https://api.upstox.com/v3/order/gtt/place');
      _expectAuthJson(g);
      expect(jsonDecode(g.body), {
        'type': 'MULTIPLE',
        'quantity': 75,
        'product': 'D',
        'instrument_token': 'NSE_FO|43885',
        'transaction_type': 'BUY',
        'rules': [
          {'strategy': 'ENTRY', 'trigger_type': 'BELOW', 'trigger_price': 420},
          {'strategy': 'TARGET', 'trigger_type': 'IMMEDIATE', 'trigger_price': 540},
          {'strategy': 'STOPLOSS', 'trigger_type': 'IMMEDIATE', 'trigger_price': 300},
        ],
      });
      expect(orders.single.kind, 'GTT entry+SL 300.0+TGT 540.0');
      expect(orders.single.id, 'GTT-1');
    });

    String entryTrigger(http.Request gtt) =>
        ((jsonDecode(gtt.body) as Map)['rules'] as List).first['trigger_type'] as String;

    test('buy entry is IMMEDIATE when the LTP is at or below the entry', () async {
      final (log, _) = await placeGtt(plan(product: ProductType.intraday), ltp: 400);
      expect(entryTrigger(log[1]), 'IMMEDIATE');
      expect((jsonDecode(log[1].body) as Map)['product'], 'I');
      final (log2, _) = await placeGtt(plan(), ltp: 420);
      expect(entryTrigger(log2[1]), 'IMMEDIATE');
    });

    test('sell entry waits ABOVE when the LTP is below the entry', () async {
      final (log, _) = await placeGtt(plan(action: TradeAction.sell, sl: 540, tgt: 300), ltp: 400);
      final body = jsonDecode(log[1].body) as Map;
      expect(body['transaction_type'], 'SELL');
      expect(entryTrigger(log[1]), 'ABOVE');
      expect(body['rules'][1], {'strategy': 'TARGET', 'trigger_type': 'IMMEDIATE', 'trigger_price': 300});
      expect(body['rules'][2], {'strategy': 'STOPLOSS', 'trigger_type': 'IMMEDIATE', 'trigger_price': 540});
    });

    test('sell entry is IMMEDIATE when the LTP is at or above the entry', () async {
      final (log, _) = await placeGtt(plan(action: TradeAction.sell, sl: 540, tgt: 300), ltp: 450);
      expect(entryTrigger(log[1]), 'IMMEDIATE');
    });

    test('falls back to the entry price (IMMEDIATE) when the LTP lookup fails', () async {
      final (log, orders) = await placeGtt(plan());
      expect(log, hasLength(2));
      expect(entryTrigger(log[1]), 'IMMEDIATE');
      expect(orders, hasLength(1));
      final (logSell, _) = await placeGtt(plan(action: TradeAction.sell, sl: 540, tgt: 300));
      expect(entryTrigger(logSell[1]), 'IMMEDIATE');
    });

    test('GTT errors are surfaced', () async {
      final api = UpstoxApi(
        _account,
        MockClient((r) async {
          if (r.url.path.endsWith('/market-quote/ltp')) {
            return _ok({
              'X': {'last_price': 410},
            });
          }
          return _err(400, 'Invalid trigger price');
        }),
        '',
      );
      await expectLater(api.placeTrade(_inst, plan()), _brokerError('Upstox: Invalid trigger price'));
    });
  });
}
