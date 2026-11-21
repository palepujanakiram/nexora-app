import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';
import 'package:nexora_app/screens/feed/model/feed_state.dart';

void main() {
  test('starts loading with an empty feed', () {
    const state = FeedState();
    expect(state.loading, isTrue);
    expect(state.isEmpty, isTrue);
    expect(state.error, isNull);
    expect(state.lastUpdated, isNull);
  });

  test('isEmpty reflects the feed once one arrives', () {
    const empty = FeedState(loading: false, feed: EpsFeed());
    expect(empty.isEmpty, isTrue);

    const withData = FeedState(
      loading: false,
      feed: EpsFeed(symbols: [
        EpsSymbolSignals(symbol: 'NIFTY', ruleTimeframes: [
          EpsRuleTimeframe(
            rule: EpsRule.ep,
            timeframe: '30m',
            live: EpsTrade(
              id: 't1',
              rule: EpsRule.ep,
              side: 'BUY CE',
              entry: 100,
              stop: 90,
              initialStop: 90,
              riskPoints: 10,
              targets: [],
              status: 'active',
              open: true,
            ),
          ),
        ]),
      ]),
    );
    expect(withData.isEmpty, isFalse);
  });

  test('copyWith keeps fields it is not given, and clearError drops the error', () {
    const state = FeedState(loading: false, error: 'offline');
    final kept = state.copyWith(loading: true);
    expect(kept.error, 'offline');
    expect(kept.loading, isTrue);

    final cleared = state.copyWith(clearError: true);
    expect(cleared.error, isNull);
  });
}
