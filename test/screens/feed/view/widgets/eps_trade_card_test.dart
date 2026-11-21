import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';
import 'package:nexora_app/screens/feed/view/widgets/eps_trade_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, EpsTrade trade) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: EpsTradeCard(label: 'NIFTY · EP · 30m', trade: trade))));

  testWidgets('shows the side, label, status, entry, stop and named targets', (tester) async {
    await pump(
      tester,
      const EpsTrade(
        id: 't1',
        rule: EpsRule.ep,
        side: 'BUY CE',
        entry: 100,
        stop: 90,
        initialStop: 90,
        riskPoints: 10,
        targets: [EpsTarget(name: 'R1', price: 120, hit: true), EpsTarget(name: 'R2', price: 140, hit: false)],
        status: 't1',
        open: true,
      ),
    );

    expect(find.text('BUY CE'), findsOneWidget);
    expect(find.text('NIFTY · EP · 30m'), findsOneWidget);
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('90.00'), findsOneWidget);
    expect(find.text('R1 120.00 ✓  R2 140.00'), findsOneWidget);
  });

  testWidgets('shows how many times the stop moved once it differs from the initial stop', (tester) async {
    await pump(
      tester,
      const EpsTrade(
        id: 't1',
        rule: EpsRule.ep,
        side: 'BUY PE',
        entry: 100,
        stop: 95,
        initialStop: 90,
        riskPoints: 10,
        targets: [],
        status: 'active',
        open: true,
        stopMoveCount: 2,
      ),
    );

    expect(find.text('95.00 (moved from 90.00, 2x)'), findsOneWidget);
    expect(find.text('—'), findsOneWidget, reason: 'no targets');
  });

  testWidgets('shows P/L once the trade has points, with R when known', (tester) async {
    await pump(
      tester,
      const EpsTrade(
        id: 't1',
        rule: EpsRule.ep,
        side: 'BUY CE',
        entry: 100,
        stop: 90,
        initialStop: 90,
        riskPoints: 10,
        targets: [],
        status: 'stopped',
        open: false,
        points: -10,
        r: -1,
      ),
    );

    expect(find.text('-10.00 pts (-1.00R)'), findsOneWidget);
  });

  testWidgets('shows the wave and fit for an EW trade', (tester) async {
    await pump(
      tester,
      const EpsTrade(
        id: 't1',
        rule: EpsRule.ew,
        side: 'BUY CE',
        entry: 100,
        stop: 90,
        initialStop: 90,
        riskPoints: 10,
        targets: [],
        status: 't1',
        open: true,
        wave: 'Wave 3',
        fitPercent: 67,
      ),
    );

    expect(find.text('Wave 3 · 67% fit'), findsOneWidget);
  });

  testWidgets('shows a status the vendor added after their own doc (e.g. "lock") as-is', (tester) async {
    await pump(
      tester,
      const EpsTrade(
        id: 't1',
        rule: EpsRule.ep,
        side: 'BUY PE',
        entry: 100,
        stop: 90,
        initialStop: 90,
        riskPoints: 10,
        targets: [],
        status: 'lock',
        open: false,
      ),
    );

    expect(find.text('LOCK'), findsOneWidget);
  });
}
