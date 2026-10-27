import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/accounts/usecase/get_login_url_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/login_with_redirect_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/set_access_token_usecase.dart';
import 'package:nexora_app/screens/accounts/viewmodel/login_viewmodel.dart';

import '../../../fakes.dart';

class _ControlledBroker extends FakeBrokerRepository {
  Completer<String>? pending;
  Object? error;

  @override
  Future<String> exchangeToken(BrokerAccount account, String input) {
    if (error != null) return Future.error(error!);
    if (pending != null) return pending!.future;
    return super.exchangeToken(account, input);
  }
}

class _FailingSaveAccounts extends FakeAccountRepository {
  _FailingSaveAccounts(super.initial);

  @override
  Future<void> save(BrokerAccount a) async => throw StateError('disk full');
}

void main() {
  late _ControlledBroker broker;
  late FakeAccountRepository accounts;

  LoginViewModel build(BrokerAccount account, {FakeAccountRepository? repo}) {
    final r = repo ?? accounts;
    return LoginViewModel(
        account, GetLoginUrlUseCase(broker), LoginWithRedirectUseCase(broker, r), SetAccessTokenUseCase(r));
  }

  setUp(() {
    broker = _ControlledBroker();
    accounts = FakeAccountRepository([testAccount(loggedIn: false)]);
  });

  test('initial state uses the broker login URL and the zerodha code name', () {
    final vm = build(accounts.current.single);
    expect(vm.state.loginUrl, 'https://login.example/a');
    expect(vm.state.codeName, 'request_token');
    expect(vm.state.busy, isFalse);
    expect(vm.state.error, isNull);
  });

  test('upstox accounts expect a "code" parameter', () {
    final vm = build(testAccount().copyWith(broker: BrokerType.upstox));
    expect(vm.state.codeName, 'code');
  });

  test('loginWithRedirect stores the token and returns true', () async {
    final vm = build(accounts.current.single);
    expect(await vm.loginWithRedirect('req'), isTrue);
    expect(accounts.current.single.accessToken, 'token-req');
    expect(vm.state.busy, isFalse);
    expect(vm.state.error, isNull);
  });

  test('blank input is ignored', () async {
    final vm = build(accounts.current.single);
    var notified = 0;
    vm.addListener(() => notified++);
    expect(await vm.loginWithRedirect('   '), isFalse);
    expect(await vm.useAccessToken(''), isFalse);
    expect(notified, 0);
  });

  test('is busy while exchanging and ignores a second submit', () async {
    broker.pending = Completer<String>();
    final vm = build(accounts.current.single);

    final first = vm.loginWithRedirect('req');
    expect(vm.state.busy, isTrue);
    expect(await vm.useAccessToken('tok'), isFalse);

    broker.pending!.complete('done');
    expect(await first, isTrue);
    expect(vm.state.busy, isFalse);
    expect(accounts.current.single.accessToken, 'done');
  });

  test('a failed exchange surfaces the error, which clears on the next attempt', () async {
    broker.error = Exception('invalid request_token');
    final vm = build(accounts.current.single);

    expect(await vm.loginWithRedirect('bad'), isFalse);
    expect(vm.state.error, 'Exception: invalid request_token');
    expect(vm.state.busy, isFalse);
    expect(accounts.current.single.accessToken, isNull);

    broker.error = null;
    expect(await vm.loginWithRedirect('good'), isTrue);
    expect(vm.state.error, isNull);
  });

  test('useAccessToken saves the trimmed token', () async {
    final vm = build(accounts.current.single);
    expect(await vm.useAccessToken(' tok '), isTrue);
    expect(accounts.current.single.accessToken, 'tok');
  });

  test('useAccessToken reports storage failures', () async {
    final repo = _FailingSaveAccounts([testAccount(loggedIn: false)]);
    final vm = build(repo.current.single, repo: repo);
    expect(await vm.useAccessToken('tok'), isFalse);
    expect(vm.state.error, contains('disk full'));
  });

  test('Groww has no redirect: the code is an optional TOTP and an empty input logs in', () async {
    final groww = testAccount(loggedIn: false).copyWith(broker: BrokerType.groww);
    final repo = FakeAccountRepository([groww]);
    final vm = build(groww, repo: repo);
    expect(vm.state.redirectLogin, isFalse);
    expect(vm.state.codeName, 'TOTP code');

    expect(await vm.loginWithRedirect(''), isTrue);
    expect(repo.current.single.accessToken, 'token-');
    expect(await vm.useAccessToken(' '), isFalse, reason: 'a pasted access token still needs text');
  });

  test('Upstox uses the code parameter and a redirect login', () {
    final vm = build(testAccount().copyWith(broker: BrokerType.upstox));
    expect(vm.state.codeName, 'code');
    expect(vm.state.redirectLogin, isTrue);
  });
}
