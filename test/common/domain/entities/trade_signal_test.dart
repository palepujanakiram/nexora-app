import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/trade_signal.dart';

TradeSignal _sig({
  TradeAction action = TradeAction.buy,
  String underlying = 'SENSEX',
  OptionType type = OptionType.put,
  double strike = 73100,
  double low = 400,
  double high = 420,
  DateTime? expiry,
}) =>
    TradeSignal(
      action: action,
      underlying: underlying,
      expiry: expiry ?? DateTime(2026, 10, 29),
      strike: strike,
      optionType: type,
      entryLow: low,
      entryHigh: high,
      stopLoss: 300,
      targets: const [540, 600],
      raw: 'raw text',
    );

void main() {
  test('stores fields and defaults warnings to empty', () {
    final s = _sig();
    expect(s.stopLoss, 300);
    expect(s.targets, [540, 600]);
    expect(s.raw, 'raw text');
    expect(s.warnings, isEmpty);
  });

  test('buy side', () {
    final s = _sig();
    expect(s.isBuy, isTrue);
    expect(s.side, 'BUY');
    expect(s.exitSide, 'SELL');
  });

  test('sell side', () {
    final s = _sig(action: TradeAction.sell);
    expect(s.isBuy, isFalse);
    expect(s.side, 'SELL');
    expect(s.exitSide, 'BUY');
  });

  test('optionCode', () {
    expect(_sig(type: OptionType.call).optionCode, 'CE');
    expect(_sig(type: OptionType.put).optionCode, 'PE');
  });

  test('exchange is BFO for BSE underlyings and NFO otherwise', () {
    for (final u in bseUnderlyings) {
      expect(_sig(underlying: u).exchange, 'BFO', reason: u);
    }
    expect(_sig(underlying: 'NIFTY').exchange, 'NFO');
    expect(_sig(underlying: 'BANKNIFTY').exchange, 'NFO');
  });

  test('expiryIso is yyyy-MM-dd', () {
    expect(_sig(expiry: DateTime(2026, 1, 5)).expiryIso, '2026-01-05');
  });

  test('contractLabel formats date uppercase and whole strikes without decimals', () {
    expect(_sig().contractLabel, 'SENSEX 29 OCT 2026 73100 PE');
    expect(
      _sig(underlying: 'NIFTY', type: OptionType.call, strike: 24050.5, expiry: DateTime(2026, 3, 3)).contractLabel,
      'NIFTY 03 MAR 2026 24050.50 CE',
    );
  });

  test('entryLabel shows a range or a single price', () {
    expect(_sig().entryLabel, '400–420');
    expect(_sig(low: 410, high: 410).entryLabel, '410');
    expect(_sig(low: 10.5, high: 12.25).entryLabel, '10.50–12.25');
  });
}
