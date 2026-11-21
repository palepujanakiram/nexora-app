import '../../domain/entities/eps_signal.dart';

/// Maps the EMA Pivot signals API's JSON (see proxy/cloudflare-worker's
/// `/signals` route and the vendor's own doc) onto [EpsFeed]. Rows marked
/// `measured: false` (the vendor's testing shows they lose money) are
/// dropped here, not just left for the UI to filter.
abstract final class EpsFeedModel {
  static EpsFeed fromJson(Map<String, dynamic> json) {
    final symbols = (json['symbols'] as List?) ?? const [];
    return EpsFeed(
      symbols: [for (final s in symbols) _symbol(s as Map<String, dynamic>)],
    );
  }

  static EpsSymbolSignals _symbol(Map<String, dynamic> json) {
    final intervals = (json['intervals'] as List?) ?? const [];
    return EpsSymbolSignals(
      symbol: json['symbol'] as String? ?? '',
      intervals: [for (final i in intervals) _interval(i as Map<String, dynamic>)],
    );
  }

  static EpsInterval _interval(Map<String, dynamic> json) {
    final history = (json['history'] as List?) ?? const [];
    return EpsInterval(
      timeframe: json['timeframe'] as String? ?? '',
      levels: _levels(json['levels']),
      bias: json['bias'] as String?,
      liveTrade: _trade(json['liveTrade']),
      history: [
        for (final h in history) _trade(h),
      ].whereType<EpsTrade>().toList(),
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

  /// Returns null for a missing trade, or one marked `measured: false`.
  static EpsTrade? _trade(Object? json) {
    if (json is! Map) return null;
    if (json['measured'] == false) return null;
    final targets = (json['targets'] as List?) ?? const [];
    final stopMoves = (json['stopMoves'] as List?) ?? const [];
    return EpsTrade(
      id: json['id'] as String? ?? '',
      side: json['side'] as String? ?? '',
      entry: _num(json['entry']),
      stop: _num(json['stop']),
      initialStop: _num(json['initialStop']),
      riskPoints: _num(json['riskPoints']),
      targets: [
        for (final t in targets)
          if (t is Map) EpsTarget(price: _num(t['price']), hit: t['hit'] == true),
      ],
      status: EpsTradeStatus.fromApi(json['status'] as String?),
      points: json['points'] is num ? (json['points'] as num).toDouble() : null,
      r: json['r'] is num ? (json['r'] as num).toDouble() : null,
      stopMoveCount: stopMoves.length,
    );
  }

  static double _num(Object? value) => value is num ? value.toDouble() : 0;
}
