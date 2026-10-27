import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/common/domain/entities/trade_plan.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/common/domain/usecases/watch_accounts_usecase.dart';
import 'package:nexora_app/common/domain/usecases/watch_settings_usecase.dart';
import 'package:nexora_app/common/presentation/widgets/execution_result_card.dart';
import 'package:nexora_app/common/presentation/widgets/info_banner.dart';
import 'package:nexora_app/screens/signal/usecase/execute_signal_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/parse_signal_usecase.dart';
import 'package:nexora_app/screens/signal/view/signal_view.dart';
import 'package:nexora_app/screens/signal/view/widgets/signal_summary_card.dart';

import '../../../fakes.dart';

/// Holds live orders until [release] is called, to observe the busy state.
class _GatedBrokerRepository extends FakeBrokerRepository {
  final gate = Completer<void>();

  @override
  Future<List<PlacedOrder>> placeTrade(BrokerAccount account, ResolvedInstrument i, TradePlan plan) async {
    await gate.future;
    return super.placeTrade(account, i, plan);
  }
}

void main() {
  const valid = 'BUY SENSEX 29 OCT 2026 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600';

  late FakeAccountRepository accounts;
  late FakeBrokerRepository brokers;
  late FakeActivityRepository activity;

  Future<void> register({List<BrokerAccount> initial = const [], FakeBrokerRepository? broker}) async {
    accounts = FakeAccountRepository(initial);
    brokers = broker ?? FakeBrokerRepository();
    activity = FakeActivityRepository();
    final settings = FakeSettingsRepository();
    await sl.reset();
    sl
      ..registerFactory(() => ParseSignalUseCase(SignalParser(clock: () => DateTime(2026, 10, 27))))
      ..registerFactory(() => ExecuteSignalUseCase(brokers, accounts, settings, activity))
      ..registerFactory(() => WatchAccountsUseCase(accounts))
      ..registerFactory(() => WatchSettingsUseCase(settings));
  }

  setUp(register);

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SignalView(key: UniqueKey()))));
    await tester.pump();
  }

  Future<void> parse(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.tap(find.text('Parse signal'));
    await tester.pump();
  }

  FilledButton executeWidget(WidgetTester tester) =>
      tester.widget<FilledButton>(find.ancestor(of: find.byIcon(Icons.send), matching: find.byType(FilledButton)));

  testWidgets('starts with just the input', (tester) async {
    await pumpView(tester);
    expect(find.text('New signal'), findsOneWidget);
    expect(find.text('Parse signal'), findsOneWidget);
    expect(find.byType(InfoBanner), findsNothing);
    expect(find.byType(SignalSummaryCard), findsNothing);
    expect(find.text('Execute on'), findsNothing);
  });

  testWidgets('typing before the first parse does not parse', (tester) async {
    await pumpView(tester);
    await tester.enterText(find.byType(TextField), valid);
    await tester.pump();
    expect(find.byType(SignalSummaryCard), findsNothing);
  });

  testWidgets('parse error shows a banner, re-parses on edit, and clear resets', (tester) async {
    await pumpView(tester);
    await parse(tester, 'hello');
    expect(find.textContaining('Could not find "<BUY|SELL>'), findsOneWidget);
    expect(find.byType(SignalSummaryCard), findsNothing);

    // After a parse, edits re-parse live.
    await tester.enterText(find.byType(TextField), valid);
    await tester.pump();
    expect(find.textContaining('Could not find'), findsNothing);
    expect(find.byType(SignalSummaryCard), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Signal is empty.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.byType(InfoBanner), findsNothing);
    expect(find.byType(SignalSummaryCard), findsNothing);

    // Cleared, so typing no longer parses until Parse is tapped again.
    await tester.enterText(find.byType(TextField), 'junk');
    await tester.pump();
    expect(find.byType(InfoBanner), findsNothing);
  });

  testWidgets('warnings from the parser are shown', (tester) async {
    await pumpView(tester);
    await parse(tester, 'BUY NIFTY 30 OCT 2026 25000 CE AT 100');
    expect(find.text('No stop loss found.'), findsOneWidget);
    expect(find.text('No targets found.'), findsOneWidget);
  });

  testWidgets('without accounts it explains and cannot execute', (tester) async {
    await pumpView(tester);
    await parse(tester, valid);
    expect(find.text('Execute on'), findsOneWidget);
    expect(find.text('No broker accounts yet — add one in the Accounts tab.'), findsOneWidget);
    expect(find.text('BUY on 0 account(s)'), findsOneWidget);
    expect(executeWidget(tester).onPressed, isNull);
  });

  testWidgets('accounts follow their default and can be toggled', (tester) async {
    await register(initial: [testAccount(), testAccount(id: 'b', paper: true, enabled: false)]);
    await pumpView(tester);
    await parse(tester, valid);

    expect(find.text('No broker accounts yet — add one in the Accounts tab.'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.text('Zerodha (Kite Connect) · 2 lot(s)'), findsNWidgets(2));
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('PAPER'), findsOneWidget);
    bool checked(String label) => tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label)).value!;
    expect(checked('Test a'), isTrue);
    expect(checked('Test b'), isFalse);
    expect(find.text('BUY on 1 account(s)'), findsOneWidget);

    await tester.tap(find.text('Test b'));
    await tester.pump();
    expect(checked('Test b'), isTrue);
    expect(find.text('BUY on 2 account(s)'), findsOneWidget);

    await tester.tap(find.text('Test a'));
    await tester.tap(find.text('Test b'));
    await tester.pump();
    expect(find.text('BUY on 0 account(s)'), findsOneWidget);
    expect(executeWidget(tester).onPressed, isNull);

    // Accounts added elsewhere appear.
    await accounts.save(testAccount(id: 'c'));
    await tester.pump();
    expect(find.text('Test c'), findsOneWidget);
    expect(find.text('BUY on 1 account(s)'), findsOneWidget);
  });

  testWidgets('paper-only run asks with paper wording and never places a trade', (tester) async {
    await register(initial: [testAccount(paper: true)]);
    await pumpView(tester);
    await parse(tester, valid);

    await tester.tap(find.text('BUY on 1 account(s)'));
    await tester.pumpAndSettle();
    expect(find.text('Run paper trade?'), findsOneWidget);
    expect(find.text('BUY SENSEX 29 OCT 2026 73100 PE\n\n1 account(s): Test a'), findsOneWidget);
    expect(find.textContaining('real orders'), findsNothing);
    final run = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Run'));
    expect(run.style, isNull);

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);
    expect(find.byType(ExecutionResultCard), findsOneWidget);
    expect(find.text('Test a (paper)'), findsOneWidget);
    expect(brokers.placed, isEmpty);
    expect(activity.current.single.paper, isTrue);
  });

  testWidgets('live run warns, can be cancelled, and places orders when confirmed', (tester) async {
    await register(initial: [testAccount(), testAccount(id: 'p', paper: true)]);
    await pumpView(tester);
    await parse(tester, valid);

    await tester.tap(find.text('BUY on 2 account(s)'));
    await tester.pumpAndSettle();
    expect(find.text('Place LIVE orders?'), findsOneWidget);
    expect(
      find.text('BUY SENSEX 29 OCT 2026 73100 PE\n\n2 account(s): Test a, Test p\n\n'
          '1 account(s) will send real orders to the broker.'),
      findsOneWidget,
    );
    final place = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Place orders'));
    expect(place.style, isNotNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Place LIVE orders?'), findsNothing);
    expect(find.text('Results'), findsNothing);
    expect(brokers.placed, isEmpty);
    expect(activity.current, isEmpty);

    // Dismissing by tapping outside also does nothing.
    await tester.tap(find.text('BUY on 2 account(s)'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Place LIVE orders?'), findsNothing);
    expect(brokers.placed, isEmpty);

    await tester.tap(find.text('BUY on 2 account(s)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place orders'));
    await tester.pumpAndSettle();
    expect(brokers.placed, hasLength(1));
    expect(find.text('Results'), findsOneWidget);
    expect(find.byType(ExecutionResultCard), findsNWidgets(2));
    expect(find.text('Test a'), findsWidgets);
    expect(find.text('Test p (paper)'), findsOneWidget);
    expect(activity.current, hasLength(2));
  });

  testWidgets('shows progress and disables execute while orders are in flight', (tester) async {
    final gated = _GatedBrokerRepository();
    await register(initial: [testAccount()], broker: gated);
    await pumpView(tester);
    await parse(tester, valid);

    await tester.tap(find.text('BUY on 1 account(s)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place orders'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
    final busyButton = tester.widget<FilledButton>(
        find.ancestor(of: find.byType(CircularProgressIndicator), matching: find.byType(FilledButton)));
    expect(busyButton.onPressed, isNull);

    gated.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Results'), findsOneWidget);
    expect(gated.placed, hasLength(1));
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(activity.current.single.success, isTrue);
    expect(activity.current.single, isA<ExecutionResult>());
  });
}
