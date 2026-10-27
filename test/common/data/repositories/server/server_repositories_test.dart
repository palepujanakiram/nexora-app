import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

import 'fake_server.dart';

void main() {
  group('ServerAccountRepository', () {
    test('refresh loads accounts and their login pages', () async {
      final fake = FakeServer({
        'GET /v1/accounts': (_) => {
              'accounts': [accountJson(), accountJson(id: 'acc2', loggedIn: true)],
            },
      });
      final repo = ServerAccountRepository(fake.api());
      await repo.refresh();
      expect(repo.current.map((a) => a.id), ['acc1', 'acc2']);
      expect(repo.current[1].hasValidToken, isTrue);
      expect(repo.loginUrlFor('acc2'), 'https://login.example/acc2');
      expect(repo.loginUrlFor('missing'), '');
      expect(await repo.watch().first, repo.current);
    });

    test('save creates new accounts with every field', () async {
      final fake = FakeServer({'POST /v1/accounts': (_) => accountJson(id: 'server-id')});
      final repo = ServerAccountRepository(fake.api());
      await repo.save(const BrokerAccount(
        id: 'local-uuid',
        broker: BrokerType.upstox,
        label: 'Family',
        apiKey: 'upkey1234',
        apiSecret: 'upsecret',
        redirectUri: 'https://127.0.0.1/',
      ));
      expect(fake.bodyOf('POST /v1/accounts')['apiSecret'], 'upsecret');
      expect(repo.current.single.id, 'server-id');
    });

    test('save sends only what changed, and skips the server when nothing did', () async {
      final fake = FakeServer({
        'GET /v1/accounts': (_) => {
              'accounts': [accountJson()],
            },
        'PATCH /v1/accounts/acc1': (_) => accountJson(lots: 5),
      });
      final repo = ServerAccountRepository(fake.api());
      await repo.refresh();
      final account = repo.current.single;

      await repo.save(account.copyWith(lots: 5));
      expect(fake.bodyOf('PATCH /v1/accounts/acc1'), {'lots': 5});
      expect(repo.current.single.lots, 5);

      final requests = fake.requests.length;
      await repo.save(repo.current.single.copyWith(accessToken: 'x', tokenIssuedAt: DateTime.now()));
      expect(fake.requests.length, requests, reason: 'a token-only change stays local');
      expect(repo.current.single.hasValidToken, isTrue);
    });

    test('delete removes it on the server and here; putFromServer applies a reply', () async {
      final fake = FakeServer({
        'GET /v1/accounts': (_) => {
              'accounts': [accountJson(), accountJson(id: 'acc2')],
            },
        'DELETE /v1/accounts/acc1': (_) => http.Response('', 204),
      });
      final repo = ServerAccountRepository(fake.api());
      await repo.refresh();
      await repo.delete('acc1');
      expect(repo.current.map((a) => a.id), ['acc2']);
      expect(repo.loginUrlFor('acc1'), '');

      repo.putFromServer(accountJson(id: 'acc2', loggedIn: true));
      expect(repo.current.single.hasValidToken, isTrue);
    });
  });

  group('ServerActivityRepository', () {
    test('refresh loads the shared log; addAll shows new results; clear deletes', () async {
      final fake = FakeServer({
        'GET /v1/activity': (_) => {
              'results': [resultJson()],
            },
        'DELETE /v1/activity': (_) => http.Response('', 204),
      });
      final repo = ServerActivityRepository(fake.api());
      await repo.refresh();
      expect(fake.requests.single.url.query, 'limit=200');
      expect(repo.current.single.accountId, 'acc1');

      final newer = ExecutionResult(
        accountLabel: 'X',
        broker: 'Upstox',
        signalText: 's',
        paper: true,
        time: DateTime.utc(2026),
      );
      await repo.addAll([newer]);
      expect(repo.current.first, newer);
      expect(fake.requests, hasLength(1), reason: 'the server already recorded it');

      await repo.clear();
      expect(repo.current, isEmpty);
      expect(await repo.watch().first, isEmpty);
    });
  });

  group('ServerBrokerRepository', () {
    test('logs in through the server and never handles orders', () async {
      final fake = FakeServer({
        'GET /v1/accounts': (_) => {
              'accounts': [accountJson()],
            },
        'POST /v1/accounts/acc1/session': (_) => accountJson(loggedIn: true),
      });
      final accounts = ServerAccountRepository(fake.api());
      await accounts.refresh();
      final brokers = ServerBrokerRepository(fake.api(), accounts);
      final account = accounts.current.single;

      expect(brokers.acceptsAccessTokens, isFalse);
      expect(brokers.loginUrl(account), 'https://login.example/acc1');
      expect(await brokers.exchangeToken(account, 'https://127.0.0.1/?code=X'), ServerAccountModel.serverToken);
      expect(fake.bodyOf('POST /v1/accounts/acc1/session'), {'input': 'https://127.0.0.1/?code=X'});
      expect(accounts.current.single.hasValidToken, isTrue);

      final signal = SignalParser(clock: () => DateTime(2026, 10, 27)).parse('BUY NIFTY 30 OCT 24000 PE AT 100');
      expect(() => brokers.resolve(account, signal), throwsUnsupportedError);
      const inst = ResolvedInstrument(symbol: 'X', exchange: 'NFO', lotSize: 75);
      final plan = TradePlan(signal: signal, quantity: 75, entryPrice: 100, product: ProductType.intraday);
      expect(() => brokers.placeTrade(account, inst, plan), throwsUnsupportedError);
    });
  });

  group('ServerSignalExecutionRepository', () {
    test('sends the signal text, accounts and settings, and maps the results', () async {
      final fake = FakeServer({
        'POST /v1/signals/execute': (_) => {
              'results': [
                resultJson(),
                resultJson(accountId: 'acc2', error: 'Already placed', errorCode: 'duplicate'),
              ],
            },
      });
      final signal = SignalParser(clock: () => DateTime(2026, 10, 27)).parse('BUY NIFTY 30 OCT 24000 PE AT 100');
      final results = await ServerSignalExecutionRepository(fake.api()).execute(
        signal,
        {'acc1', 'acc2'},
        const AppSettings(entryPriceMode: EntryPriceMode.mid, exitMode: ExitMode.entryOnly, targetIndex: 1),
        allowDuplicate: true,
      );
      expect(fake.bodyOf('POST /v1/signals/execute'), {
        'text': 'BUY NIFTY 30 OCT 24000 PE AT 100',
        'accountIds': ['acc1', 'acc2'],
        'settings': {'entryPriceMode': 'mid', 'exitMode': 'entryOnly', 'targetIndex': 1},
        'allowDuplicate': true,
      });
      expect(results.map((r) => r.success), [true, false]);
      expect(results[1].isDuplicate, isTrue);
      expect(results[1].accountId, 'acc2');
    });
  });
}
