import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/common/error/exceptions.dart';

void main() {
  final parser = SignalParser(clock: () => DateTime(2026, 10, 27, 9, 30));

  test('parses the reference SENSEX signal', () {
    final s = parser.parse(
      'BUY SENSEX 29 OCT 73100 PUT AT 400-420 WITH SL OF 300 TGT1 540, TGT2 600',
    );
    expect(s.action, TradeAction.buy);
    expect(s.underlying, 'SENSEX');
    expect(s.expiry, DateTime(2026, 10, 29));
    expect(s.strike, 73100);
    expect(s.optionType, OptionType.put);
    expect(s.optionCode, 'PE');
    expect(s.exchange, 'BFO');
    expect(s.entryLow, 400);
    expect(s.entryHigh, 420);
    expect(s.stopLoss, 300);
    expect(s.targets, [540, 600]);
    expect(s.warnings, isEmpty);
  });

  test('handles lowercase, @, explicit year, CE and slash targets', () {
    final s = parser.parse('sell nifty 30-oct-2026 24500 ce @ 120 to 125 sl 160 target 90/70');
    expect(s.action, TradeAction.sell);
    expect(s.underlying, 'NIFTY');
    expect(s.exchange, 'NFO');
    expect(s.expiry, DateTime(2026, 10, 30));
    expect(s.optionType, OptionType.call);
    expect(s.entryLow, 120);
    expect(s.entryHigh, 125);
    expect(s.stopLoss, 160);
    expect(s.targets, [90, 70]);
    expect(s.warnings, isEmpty);
  });

  test('rolls a past day/month into next year', () {
    final s = parser.parse('BUY BANKNIFTY 2 JAN 52000 CALL AT 300 SL 250 TGT 360');
    expect(s.expiry, DateTime(2027, 1, 2));
    expect(s.entryLow, 300);
    expect(s.entryHigh, 300);
    expect(s.targets, [360]);
  });

  test('does not confuse "TGT 540" with a target index', () {
    final s = parser.parse('BUY SENSEX 29 OCT 73100 PE 400 SL 300 TGT 540 TARGET 2: 600');
    expect(s.targets, [540, 600]);
  });

  test('targets before stop loss are not polluted by the SL value', () {
    final s = parser.parse('BUY NIFTY 30 OCT 24000 PE AT 100 TGT 130, 150 SL 80');
    expect(s.targets, [130, 150]);
    expect(s.stopLoss, 80);
  });

  test('warns when stop loss is on the wrong side', () {
    final s = parser.parse('BUY NIFTY 30 OCT 24000 PE AT 100 SL 120 TGT 150');
    expect(s.warnings, contains('Stop loss is on the wrong side of the entry price.'));
  });

  test('throws for text that is not a signal', () {
    expect(() => parser.parse('Good morning traders!'), throwsA(isA<SignalParseException>()));
  });

  test('throws for an impossible date', () {
    expect(
      () => parser.parse('BUY NIFTY 31 NOV 24000 PE AT 100 SL 80'),
      throwsA(isA<SignalParseException>()),
    );
  });
}
