import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';
import 'package:nexora_app/screens/feed/usecase/load_signals_feed_usecase.dart';
import 'package:nexora_app/screens/feed/view/feed_view.dart';
import 'package:nexora_app/screens/feed/view/widgets/eps_trade_card.dart';

import '../../../fakes.dart';

void main() {
  late FakeEpsSignalsRepository repo;

  setUp(() {
    repo = FakeEpsSignalsRepository();
    sl
      ..reset()
      ..registerFactory(() => LoadSignalsFeedUseCase(repo));
  });

  Future<void> pumpView(WidgetTester tester, {bool configured = true}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FeedView(configured: configured))));
  }

  testWidgets('not configured shows setup instructions and never calls the repository', (tester) async {
    await pumpView(tester, configured: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('isn\'t set up yet'), findsOneWidget);
    expect(repo.calls, 0);
  });

  testWidgets('always shows the "not investment advice" disclaimer, even while empty', (tester) async {
    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('not investment advice'), findsOneWidget);
    expect(find.text('No live NIFTY/SENSEX signals right now.'), findsOneWidget);
  });

  testWidgets('lists symbols, intervals, live trades and history', (tester) async {
    repo.toReturn = const EpsFeed(symbols: [
      EpsSymbolSignals(symbol: 'NIFTY', intervals: [
        EpsInterval(
          timeframe: '30m',
          bias: 'bullish',
          liveTrade: EpsTrade(
            id: 'live-1',
            side: 'BUY CE',
            entry: 100,
            stop: 90,
            initialStop: 90,
            riskPoints: 10,
            targets: [],
            status: EpsTradeStatus.active,
          ),
          history: [
            EpsTrade(
              id: 'hist-1',
              side: 'BUY PE',
              entry: 50,
              stop: 60,
              initialStop: 60,
              riskPoints: 10,
              targets: [],
              status: EpsTradeStatus.stopped,
            ),
          ],
        ),
      ]),
      EpsSymbolSignals(symbol: 'SENSEX', intervals: [EpsInterval(timeframe: '1H')]),
    ]);
    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.text('NIFTY'), findsOneWidget);
    expect(find.text('SENSEX'), findsOneWidget);
    expect(find.text('30m · Bias: bullish'), findsOneWidget);
    expect(find.text('1H'), findsOneWidget, reason: 'no bias on the SENSEX interval');
    expect(find.text('No live trade.'), findsOneWidget, reason: 'SENSEX 1H has none');
    expect(find.byType(EpsTradeCard), findsNWidgets(2));
    expect(find.textContaining('Updated '), findsOneWidget);
  });

  testWidgets('shows a load failure with Retry, which loads again', (tester) async {
    repo.toReturn = Exception('offline');
    await pumpView(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Couldn\'t load signals'), findsOneWidget);
    expect(repo.calls, 1);

    repo.toReturn = const EpsFeed();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Couldn\'t load signals'), findsNothing);
    expect(repo.calls, 2);
  });

  testWidgets('pulling to refresh loads again', (tester) async {
    await pumpView(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    await tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
  });
}
