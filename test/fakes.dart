import 'dart:async';

import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/common/domain/entities/sign_in_code.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';
import 'package:nexora_app/common/domain/repositories/account_repository.dart';
import 'package:nexora_app/common/domain/repositories/activity_repository.dart';
import 'package:nexora_app/common/domain/repositories/broker_repository.dart';
import 'package:nexora_app/common/domain/repositories/server_repository.dart';
import 'package:nexora_app/common/domain/repositories/settings_repository.dart';
import 'package:nexora_app/common/error/exceptions.dart';
import 'package:nexora_app/common/utils/reactive_cache.dart';

class FakeBrokerRepository implements BrokerRepository {
  final placed = <TradePlan>[];

  @override
  bool acceptsAccessTokens = true;

  /// When set, [loginUrl] fails with it.
  Object? loginUrlError;

  @override
  Future<String> loginUrl(BrokerAccount account) async {
    if (loginUrlError != null) throw loginUrlError!;
    return 'https://login.example/${account.id}';
  }

  @override
  Future<String> exchangeToken(BrokerAccount account, String input) async => 'token-$input';

  @override
  Future<ResolvedInstrument> resolve(BrokerAccount account, TradeSignal signal) async =>
      const ResolvedInstrument(symbol: 'SENSEX26O2973100PE', exchange: 'BFO', lotSize: 20);

  @override
  Future<List<PlacedOrder>> placeTrade(BrokerAccount account, ResolvedInstrument i, TradePlan plan) async {
    placed.add(plan);
    return [const PlacedOrder('ENTRY', '1')];
  }
}

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository([List<BrokerAccount> initial = const []]) : _cache = ReactiveCache(initial);
  final ReactiveCache<List<BrokerAccount>> _cache;

  @override
  List<BrokerAccount> get current => _cache.value;
  @override
  Stream<List<BrokerAccount>> watch() => _cache.watch();
  @override
  Future<void> save(BrokerAccount a) async =>
      _cache.value = [...current.where((x) => x.id != a.id), a];
  @override
  Future<void> delete(String id) async => _cache.value = current.where((a) => a.id != id).toList();
}

class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository([AppSettings initial = const AppSettings()]) : _cache = ReactiveCache(initial);
  final ReactiveCache<AppSettings> _cache;

  @override
  AppSettings get current => _cache.value;
  @override
  Stream<AppSettings> watch() => _cache.watch();
  @override
  Future<void> save(AppSettings s) async => _cache.value = s;
}

class FakeActivityRepository implements ActivityRepository {
  final _cache = ReactiveCache<List<ExecutionResult>>(const []);

  @override
  List<ExecutionResult> get current => _cache.value;
  @override
  Stream<List<ExecutionResult>> watch() => _cache.watch();
  @override
  Future<void> addAll(List<ExecutionResult> r) async => _cache.value = [...r, ...current];
  @override
  Future<void> clear() async => _cache.value = const [];
}

class FakeServerRepository implements ServerRepository {
  FakeServerRepository([ServerSession? initial]) : _cache = ReactiveCache(initial);
  final ReactiveCache<ServerSession?> _cache;

  /// When set, code requests, sign-in and IP lookups fail with this message.
  String? failWith;
  final calls = <String>[];

  @override
  ServerSession? get current => _cache.value;
  @override
  Stream<ServerSession?> watch() => _cache.watch();

  @override
  String? endedReason;

  /// What the server does when its token is rejected.
  void expire([String reason = 'Your session ended. Sign in again.']) {
    endedReason = reason;
    _cache.value = null;
  }

  /// The code [verifyCode] accepts.
  String code = '123456';

  /// The wait before another code is offered.
  Duration resendIn = const Duration(seconds: 30);

  /// Numbers the server has no login for.
  final unknownPhones = <String>{};

  /// When set, code requests wait for it, to show what the app does meanwhile.
  Completer<void>? hold;

  @override
  Future<SignInCode> requestCode({required String url, required String phone}) async {
    calls.add('requestCode $url $phone');
    await hold?.future;
    if (failWith != null) throw ServerApiException(failWith!);
    if (unknownPhones.contains(phone)) {
      throw ServerApiException('Sign up first.', statusCode: 404, code: 'not_registered');
    }
    return SignInCode(phone: phone, expiresIn: const Duration(minutes: 5), resendIn: resendIn);
  }

  @override
  Future<ServerSession> verifyCode({required String url, required String phone, required String code}) async {
    calls.add('verifyCode $url $phone $code');
    if (failWith != null) throw ServerApiException(failWith!);
    if (code != this.code) throw ServerApiException('Wrong code. 4 tries left.');
    return _cache.value = ServerSession(url: url, token: 'tok', phone: phone);
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _cache.value = null;
  }

  @override
  Future<String> serverIp() async {
    if (failWith != null) throw ServerApiException(failWith!);
    return '203.0.113.7';
  }
}

BrokerAccount testAccount({String id = 'a', bool paper = false, bool loggedIn = true, bool enabled = true}) =>
    BrokerAccount(
      id: id,
      broker: BrokerType.zerodha,
      label: 'Test $id',
      apiKey: 'k',
      apiSecret: 's',
      lots: 2,
      paperMode: paper,
      enabled: enabled,
      accessToken: loggedIn ? 't' : null,
      tokenIssuedAt: loggedIn ? DateTime.now() : null,
    );
