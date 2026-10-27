import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';
import 'package:nexora_app/common/domain/repositories/account_repository.dart';
import 'package:nexora_app/common/domain/repositories/activity_repository.dart';
import 'package:nexora_app/common/domain/repositories/broker_repository.dart';
import 'package:nexora_app/common/domain/repositories/settings_repository.dart';
import 'package:nexora_app/common/utils/reactive_cache.dart';

class FakeBrokerRepository implements BrokerRepository {
  final placed = <TradePlan>[];

  @override
  String loginUrl(BrokerAccount account) => 'https://login.example/${account.id}';

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
