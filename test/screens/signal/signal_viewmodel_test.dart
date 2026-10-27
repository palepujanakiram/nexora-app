import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/common/domain/usecases/watch_accounts_usecase.dart';
import 'package:nexora_app/common/domain/usecases/watch_settings_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/execute_signal_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/parse_signal_usecase.dart';
import 'package:nexora_app/screens/signal/viewmodel/signal_viewmodel.dart';

import '../../fakes.dart';

void main() {
  late FakeAccountRepository accounts;
  late SignalViewModel vm;

  setUp(() async {
    accounts = FakeAccountRepository([testAccount(), testAccount(id: 'b', enabled: false)]);
    final settings = FakeSettingsRepository();
    vm = SignalViewModel(
      ParseSignalUseCase(SignalParser(clock: () => DateTime(2026, 10, 27))),
      ExecuteSignalUseCase(FakeBrokerRepository(), accounts, settings, FakeActivityRepository()),
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
}
