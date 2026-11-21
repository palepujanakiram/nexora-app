import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';

EpsTrade _trade({bool open = true}) => EpsTrade(
      id: 't1',
      rule: EpsRule.ep,
      side: 'BUY CE',
      entry: 100,
      stop: 90,
      initialStop: 90,
      riskPoints: 10,
      targets: const [],
      status: 'active',
      open: open,
    );

void main() {
  test('EpsLevels.isEmpty reflects whether any level was parsed', () {
    expect(const EpsLevels({}).isEmpty, isTrue);
    expect(const EpsLevels({'r1': 100}).isEmpty, isFalse);
  });

  group('EpsFeed.isEmpty', () {
    test('true with no symbols', () {
      expect(const EpsFeed().isEmpty, isTrue);
    });

    test('true when every rule/timeframe has no live, pending or history', () {
      const feed = EpsFeed(symbols: [
        EpsSymbolSignals(symbol: 'NIFTY', ruleTimeframes: [EpsRuleTimeframe(rule: EpsRule.ep, timeframe: '30m')]),
      ]);
      expect(feed.isEmpty, isTrue);
    });

    test('false once any rule/timeframe has a live trade, a pending one or history', () {
      final withLive = EpsFeed(symbols: [
        EpsSymbolSignals(
          symbol: 'NIFTY',
          ruleTimeframes: [EpsRuleTimeframe(rule: EpsRule.ep, timeframe: '30m', live: _trade())],
        ),
      ]);
      expect(withLive.isEmpty, isFalse);

      final withPending = EpsFeed(symbols: [
        EpsSymbolSignals(
          symbol: 'NIFTY',
          ruleTimeframes: [EpsRuleTimeframe(rule: EpsRule.ep, timeframe: '30m', pending: _trade())],
        ),
      ]);
      expect(withPending.isEmpty, isFalse);

      final withHistory = EpsFeed(symbols: [
        EpsSymbolSignals(
          symbol: 'NIFTY',
          ruleTimeframes: [EpsRuleTimeframe(rule: EpsRule.ep, timeframe: '30m', history: [_trade(open: false)])],
        ),
      ]);
      expect(withHistory.isEmpty, isFalse);
    });
  });
}
