/// Which rule produced a trade: EP (EMA Pivot, uses pivot levels and EMAs)
/// or EW (Nexora EW, an Elliott Wave count — no pivot levels, rides a wave).
enum EpsRule { ep, ew }

/// How soon an EW target is expected, and the engine's own track record for
/// targets like it. Only EW trades carry this (EP targets have none).
class EpsTargetEta {
  const EpsTargetEta({
    required this.usualCandles,
    required this.candleRangeLow,
    required this.candleRangeHigh,
    required this.candlesGone,
    required this.expectedBy,
    required this.oddsPercent,
    required this.overdue,
  });

  final int usualCandles;
  final int candleRangeLow;
  final int candleRangeHigh;
  final int candlesGone;
  final DateTime? expectedBy;

  /// How often a target like this has hit historically, 0-100.
  final int oddsPercent;
  final bool overdue;
}

class EpsTarget {
  const EpsTarget({required this.name, required this.price, required this.hit, this.time, this.eta});

  /// 'S1'/'R2' (EP) or '1.618 × A' (EW).
  final String name;
  final double price;
  final bool hit;
  final DateTime? time;
  final EpsTargetEta? eta;
}

/// One trade — the live one on a timeframe, its pending setup, or one entry
/// in its history. [id] never changes while the trade runs, so a UI that
/// caches trades should upsert on it.
class EpsTrade {
  const EpsTrade({
    required this.id,
    required this.rule,
    required this.side,
    required this.entry,
    required this.stop,
    required this.initialStop,
    required this.riskPoints,
    required this.targets,
    required this.status,
    required this.open,
    this.entryTime,
    this.exitTime,
    this.exit,
    this.points,
    this.r,
    this.stopMoveCount = 0,
    this.wave,
    this.fitPercent,
  });

  final String id;
  final EpsRule rule;

  /// 'BUY CE' or 'BUY PE'.
  final String side;
  final double entry;
  final double stop;
  final double initialStop;
  final double riskPoints;
  final List<EpsTarget> targets;

  /// Raw status from the API ('active', 't1', 't2', 'stopped', 'lock', …).
  /// Shown as-is rather than mapped onto a fixed enum, since the vendor adds
  /// values over time (e.g. 'lock', not in their own first doc). Use [open]
  /// to know whether the trade is still running, not this string.
  final String status;
  final bool open;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final double? exit;

  /// Points made/lost; null while still open or just entered.
  final double? points;

  /// Points as a multiple of the initial risk; null while still open or just entered.
  final double? r;

  /// How many times the stop has moved (trailing). The API's stopMoves[]
  /// entries aren't modelled individually since only the count is shown.
  final int stopMoveCount;

  /// EW only: which wave this trade rides ('Wave 3', 'Wave C', 'A-B-C done', …).
  final String? wave;

  /// EW only: how well the Elliott count fits the chart, 0-100.
  final int? fitPercent;
}

/// Pivot levels or EMAs for one symbol/timeframe/rule. The API's exact key
/// names ('r1', 'fast', …) aren't fixed in the vendor's doc, so they're kept
/// as given and shown generically.
class EpsLevels {
  const EpsLevels(this.values);
  final Map<String, double> values;
  bool get isEmpty => values.isEmpty;
}

/// One (symbol, rule, timeframe): EP's or EW's signals for one timeframe of
/// one symbol. Only measured (profitable, per the vendor's own testing) rows
/// reach this far — see [EpsFeedModel].
class EpsRuleTimeframe {
  const EpsRuleTimeframe({
    required this.rule,
    required this.timeframe,
    this.bias,
    this.levels,
    this.emas,
    this.live,
    this.pending,
    this.history = const [],
  });

  final EpsRule rule;

  /// '15m', '30m', '1H' (EP) or whatever fixed set EW itself runs on.
  final String timeframe;

  /// EP only: 'BULLISH'/'BEARISH'/….
  final String? bias;

  /// EP only: pivot, r1-r3, s1-s3.
  final EpsLevels? levels;

  /// EP only: the EMAs the rule watches.
  final EpsLevels? emas;

  /// The trade currently running; null between trades.
  final EpsTrade? live;

  /// A setup that has triggered but not yet filled, if the API reports one.
  final EpsTrade? pending;

  /// Past finished trades, newest first.
  final List<EpsTrade> history;
}

class EpsSymbolSignals {
  const EpsSymbolSignals({required this.symbol, this.price, this.ruleTimeframes = const []});

  /// 'NIFTY' or 'SENSEX'.
  final String symbol;
  final double? price;
  final List<EpsRuleTimeframe> ruleTimeframes;
}

/// One poll of the EMA Pivot signals API.
class EpsFeed {
  const EpsFeed({this.symbols = const []});
  final List<EpsSymbolSignals> symbols;

  bool get isEmpty =>
      symbols.every((s) => s.ruleTimeframes.every((r) => r.live == null && r.pending == null && r.history.isEmpty));
}
