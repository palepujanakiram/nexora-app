import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/eps_signal_model.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';

void main() {
  test('parses symbols, intervals, levels, bias, live trade and history', () {
    final feed = EpsFeedModel.fromJson({
      'symbols': [
        {
          'symbol': 'NIFTY',
          'intervals': [
            {
              'timeframe': '30m',
              'bias': 'bullish',
              'levels': {'R1': 24800.5, 'S1': 24500, 'label': 'ignored-non-numeric'},
              'liveTrade': {
                'id': 'trade-1',
                'side': 'BUY CE',
                'entry': 100.5,
                'stop': 90,
                'initialStop': 85,
                'riskPoints': 15.5,
                'targets': [
                  {'price': 120, 'hit': true},
                  {'price': 140, 'hit': false},
                ],
                'status': 't1',
                'points': 20,
                'r': 1.3,
                'stopMoves': [
                  {'to': 90},
                  {'to': 95},
                ],
              },
              'history': [
                {
                  'id': 'trade-0',
                  'side': 'BUY PE',
                  'entry': 50,
                  'stop': 60,
                  'initialStop': 60,
                  'riskPoints': 10,
                  'targets': [],
                  'status': 'stopped',
                },
              ],
            },
          ],
        },
      ],
    });

    expect(feed.symbols, hasLength(1));
    final symbol = feed.symbols.single;
    expect(symbol.symbol, 'NIFTY');
    final interval = symbol.intervals.single;
    expect(interval.timeframe, '30m');
    expect(interval.bias, 'bullish');
    expect(interval.levels!.values, {'R1': 24800.5, 'S1': 24500.0});

    final live = interval.liveTrade!;
    expect(live.id, 'trade-1');
    expect(live.side, 'BUY CE');
    expect(live.entry, 100.5);
    expect(live.stop, 90.0);
    expect(live.initialStop, 85.0);
    expect(live.riskPoints, 15.5);
    expect(live.status, EpsTradeStatus.t1);
    expect(live.points, 20.0);
    expect(live.r, 1.3);
    expect(live.stopMoveCount, 2);
    expect(live.targets.map((t) => (t.price, t.hit)), [(120.0, true), (140.0, false)]);

    final history = interval.history.single;
    expect(history.id, 'trade-0');
    expect(history.status, EpsTradeStatus.stopped);
    expect(history.points, isNull);
    expect(history.r, isNull);
    expect(history.stopMoveCount, 0);
  });

  test('drops rows marked measured: false, from both the live trade and history', () {
    final feed = EpsFeedModel.fromJson({
      'symbols': [
        {
          'symbol': 'SENSEX',
          'intervals': [
            {
              'timeframe': '5m',
              'liveTrade': {
                'id': 'unmeasured-live',
                'side': 'BUY CE',
                'entry': 1,
                'stop': 1,
                'initialStop': 1,
                'riskPoints': 1,
                'targets': [],
                'status': 'active',
                'measured': false,
              },
              'history': [
                {
                  'id': 'unmeasured-history',
                  'side': 'BUY PE',
                  'entry': 1,
                  'stop': 1,
                  'initialStop': 1,
                  'riskPoints': 1,
                  'targets': [],
                  'status': 'stopped',
                  'measured': false,
                },
                {
                  'id': 'measured-history',
                  'side': 'BUY PE',
                  'entry': 1,
                  'stop': 1,
                  'initialStop': 1,
                  'riskPoints': 1,
                  'targets': [],
                  'status': 'stopped',
                  'measured': true,
                },
              ],
            },
          ],
        },
      ],
    });

    final interval = feed.symbols.single.intervals.single;
    expect(interval.liveTrade, isNull);
    expect(interval.history.map((t) => t.id), ['measured-history']);
  });

  test('tolerates missing symbols, intervals, levels and trades', () {
    expect(EpsFeedModel.fromJson({}).symbols, isEmpty);
    final feed = EpsFeedModel.fromJson({
      'symbols': [
        {'symbol': 'NIFTY', 'intervals': [{'timeframe': '1H'}]},
      ],
    });
    final interval = feed.symbols.single.intervals.single;
    expect(interval.levels, isNull);
    expect(interval.liveTrade, isNull);
    expect(interval.history, isEmpty);
    expect(interval.bias, isNull);
  });
}
