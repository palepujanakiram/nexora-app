import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/execution_result.dart';
import 'package:nexora_app/common/presentation/widgets/execution_result_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, ExecutionResult r) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: ExecutionResultCard(result: r))));

  String subtitle(WidgetTester tester) =>
      (tester.widget<ListTile>(find.byType(ListTile)).subtitle! as Text).data!;

  testWidgets('successful paper result shows symbol, quantity, price and orders', (tester) async {
    await pump(
      tester,
      ExecutionResult(
        accountLabel: 'Mine',
        broker: 'Zerodha',
        signalText: 'BUY',
        paper: true,
        time: DateTime(2026),
        symbol: 'SENSEX26O2973100PE',
        quantity: 40,
        entryPrice: 123.456,
        orders: const [PlacedOrder('ENTRY', '1'), PlacedOrder('GTT OCO', '2')],
      ),
    );

    expect(find.text('Mine (paper)'), findsOneWidget);
    expect(subtitle(tester), 'Zerodha\nSENSEX26O2973100PE\nQty 40 @ 123.46\nENTRY: 1\nGTT OCO: 2');
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.check_circle);
    expect(icon.color, Colors.green);
    expect(tester.widget<ListTile>(find.byType(ListTile)).isThreeLine, isTrue);
  });

  testWidgets('failed live result shows the error in the error colour', (tester) async {
    await pump(
      tester,
      ExecutionResult(
        accountLabel: 'Live one',
        broker: 'Upstox',
        signalText: 'BUY',
        paper: false,
        time: DateTime(2026),
        quantity: 20,
        error: 'Session expired',
      ),
    );

    expect(find.text('Live one'), findsOneWidget);
    expect(find.textContaining('(paper)'), findsNothing);
    // Quantity without a price is not shown.
    expect(subtitle(tester), 'Upstox\nSession expired');
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.error);
    expect(icon.color, Theme.of(tester.element(find.byType(ListTile))).colorScheme.error);
  });
}
