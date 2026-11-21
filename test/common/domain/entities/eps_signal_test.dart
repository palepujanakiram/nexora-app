import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';

EpsTrade _trade({EpsTradeStatus status = EpsTradeStatus.active}) => EpsTrade(
      id: 't1',
      side: 'BUY CE',
      entry: 100,
      stop: 90,
      initialStop: 90,
      riskPoints: 10,
      targets: const [],
      status: status,
    );

void main() {
  group('EpsTradeStatus.fromApi', () {
    test('maps every documented status', () {
      expect(EpsTradeStatus.fromApi('active'), EpsTradeStatus.active);
      expect(EpsTradeStatus.fromApi('t1'), EpsTradeStatus.t1);
      expect(EpsTradeStatus.fromApi('t2'), EpsTradeStatus.t2);
      expect(EpsTradeStatus.fromApi('stopped'), EpsTradeStatus.stopped);
      expect(EpsTradeStatus.fromApi('invalidated'), EpsTradeStatus.invalidated);
    });

    test('falls back to active for an unknown or missing status', () {
      expect(EpsTradeStatus.fromApi('something-new'), EpsTradeStatus.active);
      expect(EpsTradeStatus.fromApi(null), EpsTradeStatus.active);
    });
  });

  test('EpsLevels.isEmpty reflects whether any level was parsed', () {
    expect(const EpsLevels({}).isEmpty, isTrue);
    expect(const EpsLevels({'R1': 100}).isEmpty, isFalse);
  });

  group('EpsFeed.isEmpty', () {
    test('true with no symbols', () {
      expect(const EpsFeed().isEmpty, isTrue);
    });

    test('true when every interval has no live trade and no history', () {
      const feed = EpsFeed(symbols: [
        EpsSymbolSignals(symbol: 'NIFTY', intervals: [EpsInterval(timeframe: '30m')]),
      ]);
      expect(feed.isEmpty, isTrue);
    });

    test('false once any interval has a live trade or history', () {
      final withLive = EpsFeed(symbols: [
        EpsSymbolSignals(symbol: 'NIFTY', intervals: [EpsInterval(timeframe: '30m', liveTrade: _trade())]),
      ]);
      expect(withLive.isEmpty, isFalse);

      final withHistory = EpsFeed(symbols: [
        EpsSymbolSignals(symbol: 'NIFTY', intervals: [EpsInterval(timeframe: '30m', history: [_trade()])]),
      ]);
      expect(withHistory.isEmpty, isFalse);
    });
  });
}
