import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/data/models/eps_signal_model.dart';
import 'package:nexora_app/common/domain/entities/eps_signal.dart';

/// Shaped like a real response from the EMA Pivot signals API.
Map<String, dynamic> _sampleJson() => {
      'symbols': [
        {
          'symbol': 'NIFTY',
          'instrumentKey': 'NSE_INDEX|Nifty 50',
          'price': 25800.6,
          'ep': [
            {
              'tf': '30m',
              'measured': true,
              'bias': 'BULLISH',
              'levels': {'pivot': 25377.8, 'r1': 25650.8, 's1': 25241.3},
              'ema': {'fast': 25703.99, 'confirm': 25575.84},
              'pending': null,
              'live': null,
              'history': [
                {
                  'id': 'NIFTY|30m|1',
                  'symbol': 'NIFTY',
                  'tf': '30m',
                  'rule': 'EP',
                  'side': 'BUY PE',
                  'entryTime': '2026-10-07T11:15:00.000+05:30',
                  'entry': 22673.2,
                  'stop': 22704.6,
                  'initialStop': 22704.6,
                  'riskPoints': 31.4,
                  'targets': [
                    {'name': 'S1', 'price': 22633.1, 'hit': false, 'time': null},
                  ],
                  'status': 'stopped',
                  'open': false,
                  'exitTime': '2026-10-07T11:45:00.000+05:30',
                  'exit': 22704.6,
                  'points': -34.4,
                  'r': -1.1,
                  'stopMoves': [],
                },
                {
                  'id': 'NIFTY|30m|2',
                  'symbol': 'NIFTY',
                  'tf': '30m',
                  'rule': 'EP',
                  'side': 'BUY CE',
                  'entryTime': '2026-10-05T12:45:00.000+05:30',
                  'entry': 22470.45,
                  'stop': 22671.83,
                  'initialStop': 22416.62,
                  'riskPoints': 53.83,
                  'targets': [
                    {'name': 'R1', 'price': 22615.93, 'hit': true, 'time': '2026-10-06T09:15:00.000+05:30'},
                    {'name': 'R2', 'price': 22809.92, 'hit': false, 'time': null},
                  ],
                  'status': 'stopped',
                  'open': false,
                  'exitTime': '2026-10-07T09:15:00.000+05:30',
                  'exit': 22671.83,
                  'points': 198.38,
                  'r': 3.69,
                  'stopMoves': [
                    {'time': '2026-10-07T09:15:00.000+05:30', 'stop': 22671.83},
                  ],
                },
              ],
            },
            // 3m is measured: false (the vendor's own testing shows it loses money) — dropped entirely.
            {
              'tf': '3m',
              'measured': false,
              'live': {
                'id': 'unmeasured',
                'side': 'BUY CE',
                'entry': 1,
                'stop': 1,
                'initialStop': 1,
                'riskPoints': 1,
                'targets': [],
                'status': 'active',
                'open': true,
              },
              'history': [],
            },
          ],
          'ew': [
            {
              'tf': '5m',
              'measured': true,
              'lead': 'up',
              'live': {
                'id': 'NIFTY|5m|NXE|1',
                'side': 'BUY CE',
                'wave': 'Wave C',
                'fit': 85,
                'entryTime': '2026-11-20T09:50:00.000+05:30',
                'entry': 25536.55,
                'stop': 25722.2,
                'initialStop': 25345.2,
                'riskPoints': 191.35,
                'targets': [
                  {
                    'name': '1 × A',
                    'price': 25754.7,
                    'hit': true,
                    'time': '2026-11-20T14:05:00.000+05:30',
                    'eta': {
                      'usualCandles': 42,
                      'candleRange': [27, 73],
                      'candlesGone': 67,
                      'expectedBy': '2026-11-20T13:20:00.000+05:30',
                      'oddsPercent': 100,
                      'overdue': false,
                    },
                  },
                ],
                'status': 't1',
                'open': true,
                'exitTime': null,
                'exit': null,
              },
              'history': [],
            },
          ],
        },
      ],
    };

void main() {
  test('parses EP: levels, EMAs, bias and history (with and without stop moves)', () {
    final feed = EpsFeedModel.fromJson(_sampleJson());
    final symbol = feed.symbols.single;
    expect(symbol.symbol, 'NIFTY');
    expect(symbol.price, 25800.6);

    final ep = symbol.ruleTimeframes.firstWhere((r) => r.rule == EpsRule.ep);
    expect(ep.timeframe, '30m');
    expect(ep.bias, 'BULLISH');
    expect(ep.levels!.values, {'pivot': 25377.8, 'r1': 25650.8, 's1': 25241.3});
    expect(ep.emas!.values, {'fast': 25703.99, 'confirm': 25575.84});
    expect(ep.live, isNull);
    expect(ep.pending, isNull);
    expect(ep.history, hasLength(2));

    final stopped = ep.history[0];
    expect(stopped.id, 'NIFTY|30m|1');
    expect(stopped.rule, EpsRule.ep);
    expect(stopped.side, 'BUY PE');
    expect(stopped.status, 'stopped');
    expect(stopped.open, isFalse);
    expect(stopped.exit, 22704.6);
    expect(stopped.points, -34.4);
    expect(stopped.r, -1.1);
    expect(stopped.stopMoveCount, 0);
    expect(stopped.wave, isNull);
    expect(stopped.targets.single, isA<EpsTarget>().having((t) => t.name, 'name', 'S1'));

    final trailed = ep.history[1];
    expect(trailed.stopMoveCount, 1);
    expect(trailed.targets.map((t) => (t.name, t.hit)), [('R1', true), ('R2', false)]);
  });

  test('drops a whole (symbol, rule, timeframe) marked measured: false', () {
    final feed = EpsFeedModel.fromJson(_sampleJson());
    final symbol = feed.symbols.single;
    expect(symbol.ruleTimeframes.where((r) => r.timeframe == '3m'), isEmpty);
  });

  test('parses EW: wave, fit and a target\'s ETA, with no levels/EMAs', () {
    final feed = EpsFeedModel.fromJson(_sampleJson());
    final symbol = feed.symbols.single;
    final ew = symbol.ruleTimeframes.firstWhere((r) => r.rule == EpsRule.ew);
    expect(ew.timeframe, '5m');
    expect(ew.levels, isNull);
    expect(ew.emas, isNull);

    final live = ew.live!;
    expect(live.rule, EpsRule.ew);
    expect(live.wave, 'Wave C');
    expect(live.fitPercent, 85);
    expect(live.status, 't1');
    expect(live.open, isTrue);
    expect(live.points, isNull);

    final eta = live.targets.single.eta!;
    expect(eta.usualCandles, 42);
    expect(eta.candleRangeLow, 27);
    expect(eta.candleRangeHigh, 73);
    expect(eta.candlesGone, 67);
    expect(eta.expectedBy, DateTime.parse('2026-11-20T13:20:00.000+05:30'));
    expect(eta.oddsPercent, 100);
    expect(eta.overdue, isFalse);
  });

  test('tolerates missing symbols, ep/ew lists, levels and trades', () {
    expect(EpsFeedModel.fromJson({}).symbols, isEmpty);
    final feed = EpsFeedModel.fromJson({
      'symbols': [
        {
          'symbol': 'SENSEX',
          'ep': [
            {'tf': '1H', 'measured': true},
          ],
        },
      ],
    });
    final rtf = feed.symbols.single.ruleTimeframes.single;
    expect(rtf.levels, isNull);
    expect(rtf.emas, isNull);
    expect(rtf.live, isNull);
    expect(rtf.pending, isNull);
    expect(rtf.history, isEmpty);
    expect(rtf.bias, isNull);
  });
}
