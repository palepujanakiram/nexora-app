import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/common/domain/usecases/watch_accounts_usecase.dart';
import 'package:nexora_app/common/domain/usecases/watch_settings_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/execute_signal_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/parse_signal_usecase.dart';
import 'package:nexora_app/screens/signal/viewmodel/signal_viewmodel.dart';

import '../../fakes.dart';

class _FailingActivityRepository extends FakeActivityRepository {
  @override
  Future<void> addAll(List<ExecutionResult> r) async => throw StateError('disk full');
}

void main() {
  const valid = 'BUY SENSEX 29 OCT 73100 PUT AT 400-420 SL 300 TGT 540';
  late FakeAccountRepository accounts;
  late FakeSettingsRepository settings;
  late FakeBrokerRepository brokers;
  late SignalViewModel vm;

  SignalViewModel build(FakeActivityRepository activity) => SignalViewModel(
        ParseSignalUseCase(SignalParser(clock: () => DateTime(2026, 10, 27))),
        ExecuteSignalUseCase(brokers, accounts, settings, activity),
        WatchAccountsUseCase(accounts),
        WatchSettingsUseCase(settings),
      );

  setUp(() async {
    accounts = FakeAccountRepository([testAccount(), testAccount(id: 'b', enabled: false)]);
    settings = FakeSettingsRepository();
    brokers = FakeBrokerRepository();
    vm = SignalViewModel(
      ParseSignalUseCase(SignalParser(clock: () => DateTime(2026, 10, 27))),
      ExecuteSignalUseCase(brokers, accounts, settings, FakeActivityRepository()),
      WatchAccountsUseCase(accounts),
      WatchSettingsUseCase(settings),
    );
    await pumpEventQueue();
  });

  tearDown(() => vm.dispose());

  test('parse sets signal or error', () {
    vm.parse('hello');
    expect(vm.state.signal, isNull);
    expect(vm.state.error, isNotNull);

    vm.parse('BUY SENSEX 29 OCT 73100 PUT AT 400-420 SL 300 TGT 540');
    expect(vm.state.signal?.strike, 73100);
    expect(vm.state.error, isNull);
  });

  test('selection defaults to enabled accounts and picks up new ones', () async {
    expect(vm.state.chosen.map((a) => a.id), ['a']);
    vm.setSelected('b', true);
    expect(vm.state.chosen.map((a) => a.id), ['a', 'b']);

    await accounts.save(testAccount(id: 'c'));
    await pumpEventQueue();
    expect(vm.state.chosen.map((a) => a.id), containsAll(['a', 'b', 'c']));
  });

  test('execute runs on chosen accounts', () async {
    vm.parse('BUY SENSEX 29 OCT 73100 PUT AT 400-420 SL 300 TGT 540');
    final results = await vm.execute();
    expect(results.single.accountLabel, 'Test a');
    expect(vm.state.busy, isFalse);
  });

  test('picks up settings changes', () async {
    await settings.save(const AppSettings(entryPriceMode: EntryPriceMode.low));
    await pumpEventQueue();
    expect(vm.state.settings.entryPriceMode, EntryPriceMode.low);
  });

  test('onTextChanged only re-parses after a parse', () {
    vm.onTextChanged(valid);
    expect(vm.state.signal, isNull);
    expect(vm.state.error, isNull);

    vm.parse('nope');
    vm.onTextChanged(valid);
    expect(vm.state.signal?.strike, 73100);
    expect(vm.state.error, isNull);

    vm.onTextChanged('nope');
    expect(vm.state.signal, isNull);
    expect(vm.state.error, isNotNull);
  });

  test('clear drops signal and error but keeps selection', () {
    vm.setSelected('b', true);
    vm.parse(valid);
    var notified = 0;
    vm.addListener(() => notified++);
    vm.clear();
    expect(notified, 1);
    expect(vm.state.signal, isNull);
    expect(vm.state.error, isNull);
    expect(vm.state.selectionOverrides, {'b': true});
    vm.onTextChanged(valid);
    expect(vm.state.signal, isNull);
  });

  test('execute does nothing without a signal or chosen accounts', () async {
    expect(await vm.execute(), isEmpty);

    vm.parse(valid);
    vm.setSelected('a', false);
    expect(vm.state.canExecute, isFalse);
    expect(await vm.execute(), isEmpty);
    expect(brokers.placed, isEmpty);
  });

  test('execute is busy while running and sends only chosen accounts', () async {
    vm.parse(valid);
    vm.setSelected('b', true);
    final busy = <bool>[];
    vm.addListener(() => busy.add(vm.state.busy));
    final results = await vm.execute();
    expect(busy, [true, false]);
    expect(results.map((r) => r.accountLabel), unorderedEquals(['Test a', 'Test b']));
    expect(brokers.placed, hasLength(2));
  });

  test('execute clears busy even when it throws', () async {
    vm.dispose();
    vm = build(_FailingActivityRepository());
    await pumpEventQueue();
    vm.parse(valid);
    await expectLater(vm.execute(), throwsStateError);
    expect(vm.state.busy, isFalse);
  });

  test('dispose stops listening to accounts and settings', () async {
    final other = build(FakeActivityRepository());
    await pumpEventQueue();
    other.dispose();
    await accounts.save(testAccount(id: 'z'));
    await pumpEventQueue();
    expect(other.state.accounts.map((a) => a.id), isNot(contains('z')));
  });
}
