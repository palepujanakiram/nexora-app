import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexora_app/common/data/repositories/broker_repository_impl.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';

import '../../../fakes.dart';

final _signal = TradeSignal(
  action: TradeAction.buy,
  underlying: 'NIFTY',
  expiry: DateTime(2024, 10, 31),
  strike: 24000,
  optionType: OptionType.call,
  entryLow: 400,
  entryHigh: 420,
  stopLoss: null,
  targets: const [],
  raw: 'raw',
);

final _zerodha = testAccount();
final _upstox = testAccount().copyWith(broker: BrokerType.upstox, redirectUri: 'https://app.example/cb');

http.Response _ok(Object data) => http.Response(jsonEncode({'status': 'success', 'data': data}), 200);

void main() {
  late List<http.Request> log;
  late FakeSettingsRepository settings;
  late BrokerRepositoryImpl repo;

  setUp(() {
    log = [];
    settings = FakeSettingsRepository(const AppSettings(corsProxy: 'https://p.dev/'));
    repo = BrokerRepositoryImpl(
      MockClient((r) async {
        log.add(r);
        final path = r.url.path;
        if (path.endsWith('/session/token')) return _ok({'access_token': 'kite-token'});
        if (path.endsWith('/authorization/token')) return http.Response('{"access_token":"upstox-token"}', 200);
        if (path.endsWith('/instruments/NFO')) {
          return http.Response(
              'tradingsymbol,name,expiry,strike,lot_size,instrument_type,exchange,tick_size\n'
              'NIFTY24O3124000CE,NIFTY,2024-10-31,24000,25,CE,NFO,0.05\n',
              200);
        }
        if (path.endsWith('/option/contract')) {
          return _ok([
            {'instrument_type': 'CE', 'strike_price': 24000, 'trading_symbol': 'UPX', 'lot_size': 75, 'instrument_key': 'NSE_FO|1'},
          ]);
        }
        if (path.endsWith('/orders/regular')) return _ok({'order_id': 'K1'});
        if (path.endsWith('/v3/order/place')) {
          return _ok({
            'order_ids': ['U1'],
          });
        }
        return http.Response('unexpected', 404);
      }),
      settings,
    );
  });

  test('lets the user paste access tokens on this device', () {
    expect(repo.acceptsAccessTokens, isTrue);
  });

  test('finishes logins itself; an account is logged in when its token is today\'s', () async {
    expect(repo.loginFinishesOnServer, isFalse);
    expect(await repo.checkLoggedIn(testAccount()), isTrue);
    expect(await repo.checkLoggedIn(testAccount(loggedIn: false)), isFalse);
  });

  test('loginUrl routes to the account broker', () async {
    expect(await repo.loginUrl(_zerodha), 'https://kite.zerodha.com/connect/login?v=3&api_key=k');
    expect(Uri.parse(await repo.loginUrl(_upstox)).path, '/v2/login/authorization/dialog');
    expect(Uri.parse(await repo.loginUrl(_upstox)).queryParameters['redirect_uri'], 'https://app.example/cb');
    expect(await repo.loginUrl(testAccount().copyWith(broker: BrokerType.groww)), 'https://groww.in/trade-api/api-keys');
  });

  test('exchangeToken routes to the broker and applies the CORS proxy', () async {
    expect(await repo.exchangeToken(_zerodha, 'RT'), 'kite-token');
    expect(await repo.exchangeToken(_upstox, 'CODE'), 'upstox-token');
    expect(log.map((r) => r.url.toString()), [
      'https://p.dev/https://api.kite.trade/session/token',
      'https://p.dev/https://api.upstox.com/v2/login/authorization/token',
    ]);
  });

  test('reads the proxy from settings on every call', () async {
    await settings.save(const AppSettings());
    await repo.exchangeToken(_zerodha, 'RT');
    expect(log.single.url.toString(), 'https://api.kite.trade/session/token');
  });

  test('resolve routes to the broker', () async {
    final kite = await repo.resolve(_zerodha, _signal);
    expect(kite.symbol, 'NIFTY24O3124000CE');
    expect(kite.instrumentKey, isNull);
    final upx = await repo.resolve(_upstox, _signal);
    expect(upx.symbol, 'UPX');
    expect(upx.instrumentKey, 'NSE_FO|1');
    expect(log.map((r) => r.url.host), ['p.dev', 'p.dev']);
    expect(log.first.url.path, '/https://api.kite.trade/instruments/NFO');
    expect(log.last.url.path, startsWith('/https://api.upstox.com/v2/option/contract'));
  });

  test('placeTrade routes to the broker', () async {
    final plan = TradePlan(signal: _signal, quantity: 25, entryPrice: 420, product: ProductType.intraday);
    final kite = await repo.placeTrade(
        _zerodha, const ResolvedInstrument(symbol: 'S', exchange: 'NFO', lotSize: 25), plan);
    expect(kite.single.id, 'K1');
    final upx = await repo.placeTrade(
        _upstox, const ResolvedInstrument(symbol: 'S', exchange: 'NFO', lotSize: 25, instrumentKey: 'NSE_FO|1'), plan);
    expect(upx.single.id, 'U1');
    expect(log.first.bodyFields['product'], 'MIS');
    expect((jsonDecode(log.last.body) as Map)['product'], 'I');
  });
}
