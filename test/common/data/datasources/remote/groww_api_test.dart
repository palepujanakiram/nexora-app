import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/datasources/remote/groww_api.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';
import 'package:nexora_app/common/error/exceptions.dart';

final _now = DateTime.utc(2026, 10, 27, 4);
final _epoch = '${_now.millisecondsSinceEpoch ~/ 1000}';

const _account = BrokerAccount(
  id: 'g',
  broker: BrokerType.groww,
  label: 'My Groww',
  apiKey: 'gkey',
  apiSecret: 'gsecret',
  accessToken: 'gtoken',
);

TradeSignal _signal({String underlying = 'NIFTY', double strike = 24500, OptionType type = OptionType.call}) =>
    TradeSignal(
      action: TradeAction.buy,
      underlying: underlying,
      expiry: DateTime(2026, 11, 3),
      strike: strike,
      optionType: type,
      entryLow: 100,
      entryHigh: 110,
      stopLoss: 80,
      targets: const [140, 160],
      raw: 'raw',
    );

const _csvHeader = 'exchange,exchange_token,trading_symbol,groww_symbol,name,instrument_type,segment,series,isin,'
    'underlying_symbol,underlying_exchange_token,expiry_date,strike_price,lot_size,tick_size,freeze_quantity,'
    'is_reserved,buy_allowed,sell_allowed';

String _csv(List<String> rows) => [_csvHeader, ...rows, ''].join('\n');

const _rows = [
  // An equity row with a quoted name containing a comma.
  'NSE,2885,RELIANCE,NSE-RELIANCE,"Reliance Industries, Ltd",EQ,CASH,EQ,INE002A01018,,,,,1,0.05,0,0,1,1',
  // Same strike but a put, a different strike, and the wrong exchange: none should match a NIFTY call.
  'NSE,1,NIFTY26N0324500PE,NSE-NIFTY-03Nov26-24500-PE,NIFTY,PE,FNO,,,NIFTY,26000,2026-11-03,24500,75,0.05,1800,0,1,1',
  'NSE,2,NIFTY26N0324600CE,NSE-NIFTY-03Nov26-24600-CE,NIFTY,CE,FNO,,,NIFTY,26000,2026-11-03,24600,75,0.05,1800,0,1,1',
  'BSE,3,NIFTYFAKE,BSE-NIFTY,NIFTY,CE,FNO,,,NIFTY,1,2026-11-03,24500,75,0.05,1800,0,1,1',
  'NSE,4,NIFTY26N0324500CE,NSE-NIFTY-03Nov26-24500-CE,NIFTY,CE,FNO,,,NIFTY,26000,2026-11-03,24500.0,75,0.10,1800,0,1,1',
  // A BSE contract without a tick size.
  'BSE,5,SENSEX26N0373100PE,BSE-SENSEX-03Nov26-73100-PE,SENSEX,PE,FNO,,,SENSEX,1,2026-11-03,73100,20,,1000,0,1,1',
];

void main() {
  late List<http.Request> log;
  late http.Response Function(http.Request) respond;

  GrowwApi api({BrokerAccount account = _account, String proxy = ''}) => GrowwApi(
        account,
        MockClient((r) async {
          log.add(r);
          return respond(r);
        }),
        proxy,
        clock: () => _now,
      );

  setUp(() {
    log = [];
    respond = (_) => http.Response('{}', 200);
    GrowwApi.clearCache();
  });

  group('login', () {
    test('the login page is the API keys page and is never proxied', () {
      expect(api(proxy: 'https://p.dev').loginUrl(), 'https://groww.in/trade-api/api-keys');
    });

    test('an empty input uses the daily approval with a secret+timestamp checksum', () async {
      respond = (_) => http.Response(jsonEncode({'token': 'T1', 'isActive': true}), 200);
      expect(await api(proxy: 'https://p.dev/').exchangeToken('  '), 'T1');

      final r = log.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://p.dev/https://api.groww.in/v1/token/api/access');
      expect(r.headers['Authorization'], 'Bearer gkey');
      expect(r.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(r.body), {
        'key_type': 'approval',
        'checksum': sha256.convert(utf8.encode('gsecret$_epoch')).toString(),
        'timestamp': _epoch,
      });
    });

    test('a 6-digit code uses the TOTP flow; a token inside payload is accepted', () async {
      respond = (_) => http.Response(jsonEncode({'payload': {'token': 'T2'}}), 200);
      expect(await api().exchangeToken(' 123456 '), 'T2');
      expect(jsonDecode(log.single.body), {'key_type': 'totp', 'totp': '123456'});
    });

    test('anything else is rejected without a request', () async {
      await expectLater(
        api().exchangeToken('https://127.0.0.1/?code=x'),
        throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', contains('6-digit TOTP'))),
      );
      expect(log, isEmpty);
    });

    test('errors use Groww\'s message, then the HTTP status', () async {
      respond = (_) => http.Response(jsonEncode({'status': 'FAILURE', 'error': {'message': 'Key not approved'}}), 401);
      await expectLater(api().exchangeToken(''),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', 'Groww: Key not approved')));

      respond = (_) => http.Response(jsonEncode({'message': 'Bad timestamp'}), 400);
      await expectLater(api().exchangeToken(''),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', 'Groww: Bad timestamp')));

      respond = (_) => http.Response(jsonEncode({'isActive': false}), 200);
      await expectLater(api().exchangeToken(''),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', 'Groww: HTTP 200')));

      respond = (_) => http.Response(jsonEncode({'token': 'T', 'error': 'x'}), 403);
      await expectLater(api().exchangeToken(''),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', 'Groww: HTTP 403')));
    });

    test('a non-JSON error page reports the HTTP status', () async {
      respond = (_) => http.Response('<html>Bad gateway</html>', 502);
      await expectLater(api().exchangeToken(''),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', 'Groww returned HTTP 502.')));
    });
  });

  group('resolve', () {
    test('finds the NSE option from the public instrument list, through the proxy', () async {
      respond = (_) => http.Response(_csv(_rows), 200);
      final inst = await api(proxy: 'https://p.dev').resolve(_signal());
      expect(inst.symbol, 'NIFTY26N0324500CE');
      expect(inst.exchange, 'NSE');
      expect(inst.lotSize, 75);
      expect(inst.tickSize, 0.10);
      expect(log.single.url.toString(), 'https://p.dev/https://growwapi-assets.groww.in/instruments/instrument.csv');
    });

    test('SENSEX options are looked up on BSE; a missing tick size defaults to 0.05', () async {
      respond = (_) => http.Response(_csv(_rows), 200);
      final inst = await api().resolve(_signal(underlying: 'SENSEX', strike: 73100, type: OptionType.put));
      expect(inst.symbol, 'SENSEX26N0373100PE');
      expect(inst.exchange, 'BSE');
      expect(inst.lotSize, 20);
      expect(inst.tickSize, 0.05);
    });

    test('the instrument list is downloaded once per day', () async {
      respond = (_) => http.Response(_csv(_rows), 200);
      await api().resolve(_signal());
      await api().resolve(_signal(type: OptionType.put));
      expect(log, hasLength(1));
    });

    test('an unlisted contract is reported', () async {
      respond = (_) => http.Response(_csv(_rows), 200);
      await expectLater(
        api().resolve(_signal(strike: 99999)),
        throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', contains('No Groww contract found'))),
      );
    });

    test('a failed or empty download is reported and not cached', () async {
      respond = (_) => http.Response('nope', 404);
      await expectLater(api().resolve(_signal()),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', contains('download failed (404)'))));

      respond = (_) => http.Response('', 200);
      await expectLater(api().resolve(_signal()),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', contains('was empty'))));

      respond = (_) => http.Response(_csv(_rows), 200);
      expect((await api().resolve(_signal())).symbol, 'NIFTY26N0324500CE');
    });
  });

  group('placeTrade', () {
    const inst = ResolvedInstrument(symbol: 'NIFTY26N0324500CE', exchange: 'NSE', lotSize: 75);

    TradePlan plan({ProductType product = ProductType.carryForward, bool exits = true}) => TradePlan(
          signal: _signal(),
          quantity: 75,
          entryPrice: 109.999,
          product: product,
          stopLoss: exits ? 80 : null,
          target: exits ? 140 : null,
        );

    http.Response ok(String id) => http.Response(
        jsonEncode({
          'status': 'SUCCESS',
          'payload': {'groww_order_id': id, 'order_status': 'OPEN'},
        }),
        200);

    test('places a LIMIT FNO entry with the Groww headers and body', () async {
      respond = (_) => ok('GMK1');
      final orders = await api(proxy: 'https://p.dev').placeTrade(inst, plan(exits: false));

      expect(orders.single.kind, 'ENTRY');
      expect(orders.single.id, 'GMK1');
      final r = log.single;
      expect(r.url.toString(), 'https://p.dev/https://api.groww.in/v1/order/create');
      expect(r.headers['Authorization'], 'Bearer gtoken');
      expect(r.headers['X-API-VERSION'], '1.0');
      expect(r.headers['Accept'], 'application/json');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body, containsPair('trading_symbol', 'NIFTY26N0324500CE'));
      expect(body, containsPair('quantity', 75));
      expect(body, containsPair('price', 110.0));
      expect(body, containsPair('validity', 'DAY'));
      expect(body, containsPair('exchange', 'NSE'));
      expect(body, containsPair('segment', 'FNO'));
      expect(body, containsPair('product', 'NRML'));
      expect(body, containsPair('order_type', 'LIMIT'));
      expect(body, containsPair('transaction_type', 'BUY'));
      final ref = body['order_reference_id'] as String;
      expect(ref, matches(RegExp(r'^NX\d{16}$')));
      expect(ref.length, inInclusiveRange(8, 20));
    });

    test('intraday uses MIS; exits are reported as not placed', () async {
      respond = (_) => ok('GMK2');
      final orders = await api().placeTrade(inst, plan(product: ProductType.intraday));

      expect(jsonDecode(log.single.body)['product'], 'MIS');
      expect(log, hasLength(1), reason: 'no smart order is sent');
      expect(orders.map((o) => o.kind), ['ENTRY', 'SL 80.0 / TGT 140.0']);
      expect(orders.last.id, contains('not placed'));
    });

    test('a FAILURE response or missing payload throws Groww\'s message', () async {
      respond = (_) => http.Response(
          jsonEncode({'status': 'FAILURE', 'error': {'message': 'Insufficient margin'}}), 200);
      await expectLater(api().placeTrade(inst, plan()),
          throwsA(isA<BrokerApiException>().having((e) => e.message, 'message', 'Groww: Insufficient margin')));

      respond = (_) => http.Response(jsonEncode({'status': 'SUCCESS'}), 200);
      await expectLater(api().placeTrade(inst, plan()), throwsA(isA<BrokerApiException>()));

      respond = (_) => http.Response(jsonEncode({'status': 'SUCCESS', 'payload': {'groww_order_id': 'X'}}), 500);
      await expectLater(api().placeTrade(inst, plan()), throwsA(isA<BrokerApiException>()));
    });
  });
}
