import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/common/presentation/widgets/info_banner.dart';
import 'package:nexora_app/screens/signal/model/signal_state.dart';
import 'package:nexora_app/screens/signal/view/widgets/signal_summary_card.dart';

void main() {
  final parser = SignalParser(clock: () => DateTime(2026, 10, 27));

  Future<void> pump(WidgetTester tester, TradeSignal signal, [AppSettings settings = const AppSettings()]) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SignalSummaryCard(state: SignalState(signal: signal, settings: settings))),
        ),
      ));

  String valueOf(WidgetTester tester, String key) {
    final row = find.ancestor(of: find.text(key), matching: find.byType(Row)).first;
    final texts = tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))).toList();
    return texts.last.data!;
  }

  testWidgets('buy signal with stop and targets shows GTT exits', (tester) async {
    await pump(tester, parser.parse('BUY SENSEX 29 OCT 2026 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600'));

    final chip = tester.widget<Chip>(find.byType(Chip));
    expect((chip.label as Text).data, 'BUY');
    expect(chip.backgroundColor, Colors.green.shade100);
    expect(find.text('SENSEX 29 OCT 2026 73100 PE'), findsOneWidget);
    expect(valueOf(tester, 'Exchange'), 'BFO');
    expect(valueOf(tester, 'Entry range'), '400–420');
    expect(valueOf(tester, 'Limit price'), '420.00 (high end)');
    expect(valueOf(tester, 'Stop loss'), '300.0');
    expect(valueOf(tester, 'Targets'), '540.0, 600.0');
    expect(valueOf(tester, 'Exits'), 'GTT: SL 300.0 / TGT 540.0');
    expect(find.byType(InfoBanner), findsNothing);
  });

  testWidgets('sell signal in entry-only mode shows no exits', (tester) async {
    await pump(
      tester,
      parser.parse('SELL NIFTY 30-OCT-2026 24500 CE @ 120 TO 125 SL 160 TARGET 90/70'),
      const AppSettings(exitMode: ExitMode.entryOnly, entryPriceMode: EntryPriceMode.mid),
    );

    final chip = tester.widget<Chip>(find.byType(Chip));
    expect((chip.label as Text).data, 'SELL');
    expect(chip.backgroundColor, Colors.red.shade100);
    expect(valueOf(tester, 'Exchange'), 'NFO');
    expect(valueOf(tester, 'Limit price'), '122.50 (middle)');
    expect(valueOf(tester, 'Exits'), 'None (entry only)');
  });

  testWidgets('missing stop loss and targets show dashes and warnings', (tester) async {
    await pump(tester, parser.parse('BUY NIFTY 30 OCT 2026 25000 CE AT 100'),
        const AppSettings(entryPriceMode: EntryPriceMode.low));

    expect(valueOf(tester, 'Entry range'), '100');
    expect(valueOf(tester, 'Limit price'), '100.00 (low end)');
    expect(valueOf(tester, 'Stop loss'), '—');
    expect(valueOf(tester, 'Targets'), '—');
    expect(valueOf(tester, 'Exits'), 'None (entry only)');
    expect(find.byType(InfoBanner), findsNWidgets(2));
    expect(find.text('No stop loss found.'), findsOneWidget);
    expect(find.text('No targets found.'), findsOneWidget);
  });
}
