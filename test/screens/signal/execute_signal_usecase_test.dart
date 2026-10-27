import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/screens/signal/usecase/execute_signal_usecase.dart';

import '../../fakes.dart';

void main() {
  final signal = SignalParser(clock: () => DateTime(2026, 10, 27))
      .parse('BUY SENSEX 29 OCT 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600');

  late FakeBrokerRepository brokers;
  late FakeActivityRepository activity;

  ExecuteSignalUseCase build(List accounts, [AppSettings settings = const AppSettings()]) {
    brokers = FakeBrokerRepository();
    activity = FakeActivityRepository();
    return ExecuteSignalUseCase(
      brokers,
      FakeAccountRepository(accounts.cast()),
      FakeSettingsRepository(settings),
      activity,
    );
  }

  test('live account sends lots × lot size at the chosen entry price with exits', () async {
    final execute = build([testAccount()], const AppSettings(entryPriceMode: EntryPriceMode.mid, targetIndex: 1));
    final [r] = await execute(signal, {'a'});
    expect(r.success, isTrue, reason: r.error);
    final plan = brokers.placed.single;
    expect(plan.quantity, 40);
    expect(plan.entryPrice, 410);
    expect(plan.stopLoss, 300);
    expect(plan.target, 600);
    expect(r.symbol, 'SENSEX26O2973100PE');
    expect(activity.current, [r]);
  });

  test('paper account never places a trade', () async {
    final execute = build([testAccount(paper: true)]);
    final [r] = await execute(signal, {'a'});
    expect(r.success, isTrue);
    expect(brokers.placed, isEmpty);
    expect(r.quantity, 40);
  });

  test('live account without a session fails instead of trading', () async {
    final execute = build([testAccount(loggedIn: false)]);
    final [r] = await execute(signal, {'a'});
    expect(r.success, isFalse);
    expect(brokers.placed, isEmpty);
  });

  test('entry-only mode omits exits and only selected accounts run', () async {
    final execute = build([testAccount(), testAccount(id: 'b')], const AppSettings(exitMode: ExitMode.entryOnly));
    final results = await execute(signal, {'b'});
    expect(results.single.accountLabel, 'Test b');
    expect(brokers.placed.single.hasExits, isFalse);
    expect(brokers.placed.single.entryPrice, 420);
  });
}
