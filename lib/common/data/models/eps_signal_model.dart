import '../../domain/entities/eps_signal.dart';

/// Maps the EMA Pivot signals API's JSON (see proxy/cloudflare-worker's
/// `/signals` route) onto [EpsFeed]. A (symbol, rule, timeframe) marked
/// `measured: false` (the vendor's own testing shows it loses money) is
/// dropped here entirely, not just left for the UI to filter.
abstract final class EpsFeedModel {
  static EpsFeed fromJson(Map<String, dynamic> json) {
    final symbols = (json['symbols'] as List?) ?? const [];
    return EpsFeed(symbols: [for (final s in symbols) _symbol(s as Map<String, dynamic>)]);
  }

  static EpsSymbolSignals _symbol(Map<String, dynamic> json) {
    final ep = (json['ep'] as List?) ?? const [];
    final ew = (json['ew'] as List?) ?? const [];
    final ruleTimeframes = [
      for (final e in ep) _ruleTimeframe(EpsRule.ep, e as Map<String, dynamic>),
      for (final e in ew) _ruleTimeframe(EpsRule.ew, e as Map<String, dynamic>),
    ].whereType<EpsRuleTimeframe>().toList();
    return EpsSymbolSignals(
      symbol: json['symbol'] as String? ?? '',
      price: json['price'] is num ? (json['price'] as num).toDouble() : null,
      ruleTimeframes: ruleTimeframes,
    );
  }

  /// Null when the API marks this (symbol, rule, timeframe) `measured: false`.
  static EpsRuleTimeframe? _ruleTimeframe(EpsRule rule, Map<String, dynamic> json) {
    if (json['measured'] != true) return null;
    final history = (json['history'] as List?) ?? const [];
    return EpsRuleTimeframe(
      rule: rule,
      timeframe: json['tf'] as String? ?? '',
      bias: json['bias'] as String?,
      levels: _levels(json['levels']),
      emas: _levels(json['ema']),
      live: _trade(rule, json['live']),
      pending: _trade(rule, json['pending']),
      history: [for (final h in history) _trade(rule, h)].whereType<EpsTrade>().toList(),
    );
  }

  static EpsTrade? _trade(EpsRule rule, Object? json) {
    if (json is! Map) return null;
    final targets = (json['targets'] as List?) ?? const [];
    final stopMoves = (json['stopMoves'] as List?) ?? const [];
    return EpsTrade(
      id: json['id'] as String? ?? '',
      rule: rule,
      side: json['side'] as String? ?? '',
      entry: _num(json['entry']),
      stop: _num(json['stop']),
      initialStop: _num(json['initialStop']),
      riskPoints: _num(json['riskPoints']),
      targets: [
        for (final t in targets)
          if (t is Map) _target(t),
      ],
      status: json['status'] as String? ?? '',
      open: json['open'] == true,
      entryTime: _time(json['entryTime']),
      exitTime: _time(json['exitTime']),
      exit: json['exit'] is num ? (json['exit'] as num).toDouble() : null,
      points: json['points'] is num ? (json['points'] as num).toDouble() : null,
      r: json['r'] is num ? (json['r'] as num).toDouble() : null,
      stopMoveCount: stopMoves.length,
      wave: json['wave'] as String?,
      fitPercent: json['fit'] is num ? (json['fit'] as num).toInt() : null,
    );
  }

  static EpsTarget _target(Map target) => EpsTarget(
        name: target['name'] as String? ?? '',
        price: _num(target['price']),
        hit: target['hit'] == true,
        time: _time(target['time']),
        eta: _eta(target['eta']),
      );

  static EpsTargetEta? _eta(Object? json) {
    if (json is! Map) return null;
    final range = (json['candleRange'] as List?) ?? const [];
    return EpsTargetEta(
      usualCandles: (json['usualCandles'] as num?)?.toInt() ?? 0,
      candleRangeLow: range.isNotEmpty ? (range[0] as num).toInt() : 0,
      candleRangeHigh: range.length > 1 ? (range[1] as num).toInt() : 0,
      candlesGone: (json['candlesGone'] as num?)?.toInt() ?? 0,
      expectedBy: _time(json['expectedBy']),
      oddsPercent: (json['oddsPercent'] as num?)?.toInt() ?? 0,
      overdue: json['overdue'] == true,
    );
  }

  static EpsLevels? _levels(Object? json) {
    if (json is! Map) return null;
    final values = <String, double>{};
    for (final entry in json.entries) {
      final v = entry.value;
      if (v is num) values[entry.key as String] = v.toDouble();
    }
    return EpsLevels(values);
  }

  static DateTime? _time(Object? value) => value is String ? DateTime.tryParse(value) : null;

  static double _num(Object? value) => value is num ? value.toDouble() : 0;
}
