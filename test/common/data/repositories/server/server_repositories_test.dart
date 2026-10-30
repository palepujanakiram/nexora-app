import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexora_app/common/data/datasources/local/preferences_datasource.dart';
import 'package:nexora_app/common/data/models/server_account_model.dart';
import 'package:nexora_app/common/data/repositories/server/server_account_repository.dart';
import 'package:nexora_app/common/data/repositories/server/server_activity_repository.dart';
import 'package:nexora_app/common/data/repositories/server/server_broker_repository.dart';
import 'package:nexora_app/common/data/repositories/server/server_signal_execution_repository.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/common/error/exceptions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../fakes.dart';
import 'fake_server.dart';

void main() {
  late PreferencesDataSource prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesDataSource(await SharedPreferences.getInstance());
  });

  final signal = SignalParser(clock: () => DateTime(2026, 10, 27)).parse('BUY NIFTY 30 OCT 24000 PE AT 99-101');

  group('ServerAccountRepository', () {
    test('refresh loads accounts with this device\'s settings, skipping brokers the app lacks', () async {
      await prefs.writeJson('server_account_settings_v1', {
        'acc2': {'enabled': false, 'lots': 3, 'product': 'intraday', 'redirectUri': 'https://cb.test/'},
      });
      final fake = FakeServer({
        'GET /broker-accounts': (_) => {
              'accounts': [
                accountJson(),
                accountJson(id: 'acc2', mode: 'live', state: 'valid'),
                accountJson(id: 'acc3', broker: 'angelone'),
              ],
            },
      });
      final repo = ServerAccountRepository(fake.api(), prefs);
      await repo.refresh();
      expect(repo.current.map((a) => a.id), ['acc1', 'acc2']);
      final live = repo.current[1];
      expect([live.paperMode, live.hasValidToken, live.enabled, live.lots, live.product, live.redirectUri],
          [false, isTrue, false, 3, ProductType.intraday, 'https://cb.test/']);
      expect(repo.current[0].hasValidToken, isFalse);
      expect(await repo.watch().first, repo.current);
    });

    test('save creates new accounts with their credentials and keeps the local settings', () async {
      final fake = FakeServer({
        'POST /broker-accounts': (_) => {
              'account': accountJson(id: 'ba_new'),
              'link': {'kind': 'redirect', 'url': 'https://login.example', 'message': 'Log in.'},
            },
      });
      final repo = ServerAccountRepository(fake.api(), prefs);
      await repo.save(const BrokerAccount(
        id: 'local-uuid',
        broker: BrokerType.upstox,
        label: 'Family',
        apiKey: 'upkey1234',
        apiSecret: 'upsecret',
        redirectUri: 'https://srv.test/broker-callback/upstox',
        lots: 2,
      ));
      expect(fake.bodyOf('POST /broker-accounts'), {
        'broker': 'upstox',
        'label': 'Family',
        'mode': 'paper',
        'credentials': {
          'apiKey': 'upkey1234',
          'apiSecret': 'upsecret',
          'redirectUri': 'https://srv.test/broker-callback/upstox',
        },
      });
      expect(repo.current.single.id, 'ba_new');
      expect(repo.current.single.lots, 2);
      expect((prefs.readJson('server_account_settings_v1') as Map)['ba_new'], {
        'enabled': true,
        'lots': 2,
        'product': 'carryForward',
        'redirectUri': 'https://srv.test/broker-callback/upstox',
      });
    });

    test('save sends a mode change, keeps lots and product here, and refuses what the server can\'t change',
        () async {
      final fake = FakeServer({
        'GET /broker-accounts': (_) => {
              'accounts': [accountJson()],
            },
        'PATCH /broker-accounts/acc1': (_) => accountJson(mode: 'live'),
      });
      final repo = ServerAccountRepository(fake.api(), prefs);
      await repo.refresh();
      final account = repo.current.single;

      await repo.save(account.copyWith(lots: 5));
      expect(fake.requests, hasLength(1), reason: 'lots live on this device');
      expect(repo.current.single.lots, 5);

      await repo.save(repo.current.single.copyWith(paperMode: false));
      expect(fake.bodyOf('PATCH /broker-accounts/acc1'), {'mode': 'live'});
      expect([repo.current.single.paperMode, repo.current.single.lots], [false, 5]);

      for (final change in [
        account.copyWith(label: 'Other'),
        account.copyWith(apiSecret: 'new secret'),
        account.copyWith(broker: BrokerType.zerodha),
      ]) {
        await expectLater(repo.save(change),
            throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('Delete the account'))));
      }
    });

    test('delete removes it on the server and here; putFromServer applies a reply', () async {
      await prefs.writeJson('server_account_settings_v1', {
        'acc1': {'lots': 4},
      });
      final fake = FakeServer({
        'GET /broker-accounts': (_) => {
              'accounts': [accountJson(), accountJson(id: 'acc2')],
            },
        'DELETE /broker-accounts/acc1': (_) => http.Response('', 204),
      });
      final repo = ServerAccountRepository(fake.api(), prefs);
      await repo.refresh();
      await repo.delete('acc1');
      expect(repo.current.map((a) => a.id), ['acc2']);
      expect(prefs.readJson('server_account_settings_v1'), isEmpty);

      repo.putFromServer(accountJson(id: 'acc2', mode: 'live', state: 'valid'));
      expect(repo.current.single.hasValidToken, isTrue);
      repo.putFromServer(accountJson(id: 'acc9', broker: 'angelone'));
      expect(repo.current.map((a) => a.id), ['acc2']);
    });
  });

  group('ServerActivityRepository', () {
    test('refresh lists the orders by leg; addAll shows new results; clear hides older ones here', () async {
      final accounts = FakeAccountRepository([
        const BrokerAccount(id: 'acc1', broker: BrokerType.upstox, label: 'Family', apiKey: 'k', apiSecret: ''),
      ]);
      final fake = FakeServer({
        'GET /orders': (_) => {
              'orders': [
                orderJson(createdAt: DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String()),
                orderJson(
                    id: 'po_0',
                    createdAt: '2020-01-01T00:00:00.000Z',
                    legs: [legJson(accountId: 'gone', broker: 'angelone')]),
              ],
            },
      });
      final repo = ServerActivityRepository(fake.api(), accounts, prefs);
      await repo.refresh();
      expect(fake.requests.single.url.query, 'limit=200');
      expect(repo.current.map((r) => r.accountLabel), ['Family', 'gone']);
      expect(repo.current.first.broker, 'Upstox');
      expect(repo.current.last.broker, 'angelone');

      final newer =
          ExecutionResult(accountLabel: 'X', broker: 'Upstox', signalText: 's', paper: true, time: DateTime.utc(2026));
      await repo.addAll([newer]);
      expect(repo.current.first, newer);
      expect(fake.requests, hasLength(1), reason: 'the server already recorded it');

      await repo.clear();
      expect(repo.current, isEmpty);
      await repo.refresh();
      expect(repo.current.map((r) => r.accountLabel), ['Family'], reason: 'only orders after the clear');
      expect(await repo.watch().first, repo.current);
    });
  });

  group('ServerBrokerRepository', () {
    test('logs in through the server and never handles orders', () async {
      final fake = FakeServer({
        'GET /broker-accounts': (_) => {
              'accounts': [accountJson(mode: 'live')],
            },
        'GET /broker-accounts/acc1/relink': (_) => {'kind': 'redirect', 'url': 'https://login.example/acc1'},
        'POST /broker-accounts/acc1/link': (_) => accountJson(mode: 'live', state: 'valid'),
      });
      final accounts = ServerAccountRepository(fake.api(), prefs);
      await accounts.refresh();
      final brokers = ServerBrokerRepository(fake.api(), accounts);
      final account = accounts.current.single;

      expect(brokers.acceptsAccessTokens, isFalse);
      expect(await brokers.loginUrl(account), 'https://login.example/acc1');
      expect(await brokers.exchangeToken(account, ' https://cb.test/?code=X '), ServerAccountModel.serverToken);
      expect(fake.bodyOf('POST /broker-accounts/acc1/link'), {
        'params': {'url': 'https://cb.test/?code=X'},
      });
      expect(accounts.current.single.hasValidToken, isTrue);

      fake.routes['GET /broker-accounts/acc1/relink'] = (_) => {'kind': 'input', 'url': null, 'fields': []};
      expect(await brokers.loginUrl(account), '');

      expect(() => brokers.resolve(account, signal), throwsUnsupportedError);
      const inst = ResolvedInstrument(symbol: 'X', exchange: 'NFO', lotSize: 75);
      final plan = TradePlan(signal: signal, quantity: 75, entryPrice: 100, product: ProductType.intraday);
      expect(() => brokers.placeTrade(account, inst, plan), throwsUnsupportedError);
    });

    test('sends a bare code under the name each broker uses', () {
      BrokerAccount of(BrokerType b) => testAccount().copyWith(broker: b);
      expect(ServerBrokerRepository.linkParams(of(BrokerType.zerodha), ' rt1 '), {'request_token': 'rt1'});
      expect(ServerBrokerRepository.linkParams(of(BrokerType.upstox), 'c1'), {'code': 'c1'});
      expect(ServerBrokerRepository.linkParams(of(BrokerType.groww), '123456'), {'totp': '123456'});
      expect(ServerBrokerRepository.linkParams(of(BrokerType.groww), ' '), isEmpty);
    });
  });

  group('ServerSignalExecutionRepository', () {
    const instrumentId = 'NFO:PE:NIFTY:2026-10-30:2400000';
    BrokerAccount account(String id, {int lots = 1, ProductType product = ProductType.carryForward}) => BrokerAccount(
        id: id, broker: BrokerType.upstox, label: 'Acc $id', apiKey: 'k', apiSecret: '', lots: lots, product: product);

    FakeServer server({Object? Function(http.Request)? orders}) => FakeServer({
          'POST /signals/parse': (_) => {'instrumentId': instrumentId},
          'GET /instruments': (_) => {
                'instruments': [
                  {'id': 'other', 'lotSize': 1, 'tickSize': '0.05'},
                  {'id': instrumentId, 'lotSize': 75, 'tickSize': '0.10'},
                ],
              },
          'POST /orders': orders ??
              (req) {
                final body = jsonDecode(req.body) as Map<String, dynamic>;
                return http.Response(
                  jsonEncode({
                    'parentOrderId': 'po_1',
                    'status': 'IN_PROGRESS',
                    'legs': [
                      for (final id in (body['accountIds'] as List).cast<String>())
                        id == 'b'
                            ? legJson(
                                accountId: id,
                                status: 'REJECTED',
                                brokerOrderId: null,
                                error: {'code': 'INSUFFICIENT_FUNDS', 'message': 'Upstox: not enough margin'})
                            : legJson(accountId: id, quantity: body['quantity'] as int),
                    ],
                  }),
                  207,
                );
              },
        });

    test('places one order per lots and product, each with its own idempotency key', () async {
      final fake = server();
      final accounts = FakeAccountRepository([
        account('a'),
        account('b'),
        account('c', lots: 2, product: ProductType.intraday),
        account('unticked'),
      ]);
      var n = 0;
      final repo = ServerSignalExecutionRepository(fake.api(), accounts, newKey: () => 'key-${++n}');
      final results =
          await repo.execute(signal, {'a', 'b', 'c'}, const AppSettings(entryPriceMode: EntryPriceMode.mid));

      expect(fake.bodyOf('POST /signals/parse'), {'text': signal.raw});
      final lookup = fake.last('GET /instruments').url.queryParameters;
      expect(lookup, {'underlying': 'NIFTY', 'type': 'PE', 'expiry': '2026-10-30', 'exchange': 'NFO', 'limit': '500'});

      final orders = fake.requests.where((r) => r.url.path == '/orders').toList();
      expect(orders.map((r) => r.headers['Idempotency-Key']), ['key-1', 'key-2']);
      expect(orders.map((r) => r.headers['Authorization']), everyElement('Bearer tok'));
      expect(jsonDecode(orders[0].body), {
        'instrumentId': instrumentId,
        'side': 'BUY',
        'quantity': 75,
        'orderType': 'LIMIT',
        'product': 'CARRYFORWARD',
        'price': '100.00',
        'referencePrice': '100.00',
        'accountIds': ['a', 'b'],
      });
      expect(jsonDecode(orders[1].body), containsPair('quantity', 150));
      expect(jsonDecode(orders[1].body), containsPair('product', 'INTRADAY'));

      expect(results.map((r) => r.accountId), ['a', 'b', 'c']);
      expect(results.map((r) => r.success), [true, false, true]);
      expect(results[0].orders.single.kind, 'ENTRY · open');
      expect(results[0].orders.single.id, 'B1');
      expect([results[0].signalText, results[0].symbol, results[0].entryPrice], [signal.raw, 'NIFTY 30 OCT 2026 24000 PE', 100]);
      expect([results[1].error, results[1].errorCode], ['Upstox: not enough margin', 'INSUFFICIENT_FUNDS']);
      expect(results[2].quantity, 150);
    });

    test('a refused order fails each of its accounts with the server\'s reason', () async {
      final fake = server(
          orders: (_) =>
              http.Response('{"error":{"code":"market_closed","message":"The market is closed."}}', 422));
      final repo = ServerSignalExecutionRepository(fake.api(), FakeAccountRepository([account('a')]));
      final results = await repo.execute(signal, {'a'}, const AppSettings());
      expect([results.single.error, results.single.errorCode, results.single.accountLabel],
          ['The market is closed.', 'market_closed', 'Acc a']);
      expect(fake.last('POST /orders').headers['Idempotency-Key'], hasLength(36));
    });

    test('fails every account when the contract isn\'t in the server\'s instrument list', () async {
      final unknown = FakeServer({'POST /signals/parse': (_) => {'instrumentId': null}});
      final accounts = FakeAccountRepository([account('a'), account('b')]);
      var results = await ServerSignalExecutionRepository(unknown.api(), accounts).execute(signal, {'a', 'b'}, const AppSettings());
      expect(results.map((r) => r.error), everyElement(contains('doesn\'t list NIFTY 30 OCT 2026 24000 PE yet')));
      expect(unknown.requests, hasLength(1));

      final missing = server()..routes['GET /instruments'] = (_) => {'instruments': []};
      results = await ServerSignalExecutionRepository(missing.api(), accounts).execute(signal, {'a'}, const AppSettings());
      expect(results.single.error, contains('doesn\'t list'));
    });
  });
}
