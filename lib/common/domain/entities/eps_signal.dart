/// How a published EMA Pivot trade is doing. Unknown values from the API
/// fall back to [active] rather than failing the whole feed.
enum EpsTradeStatus {
  active,
  t1,
  t2,
  stopped,
  invalidated;

  static EpsTradeStatus fromApi(String? value) =>
      EpsTradeStatus.values.firstWhere((s) => s.name == value, orElse: () => EpsTradeStatus.active);
}

class EpsTarget {
  const EpsTarget({required this.price, required this.hit});
  final double price;
  final bool hit;
}

/// One BUY CE / BUY PE trade from the EMA Pivot engine (the live trade of an
/// interval, or one entry in its history). [id] never changes while the
/// trade runs, so a UI that caches trades should upsert on it.
class EpsTrade {
  const EpsTrade({
    required this.id,
    required this.side,
    required this.entry,
    required this.stop,
    required this.initialStop,
    required this.riskPoints,
    required this.targets,
    required this.status,
    this.points,
    this.r,
    this.stopMoveCount = 0,
  });

  final String id;

  /// 'BUY CE' or 'BUY PE'.
  final String side;
  final double entry;
  final double stop;
  final double initialStop;
  final double riskPoints;
  final List<EpsTarget> targets;
  final EpsTradeStatus status;

  /// Points made/lost so far; null while just entered.
  final double? points;

  /// Points expressed as a multiple of the initial risk; null while just entered.
  final double? r;

  /// How many times the stop has moved (trailing). The API's stopMoves[]
  /// entries aren't modelled individually since only the count is shown.
  final int stopMoveCount;
}

/// Pivot levels and EMAs for one symbol/timeframe. The API doesn't document
/// exact key names, so they're kept as given and shown generically.
class EpsLevels {
  const EpsLevels(this.values);
  final Map<String, double> values;
  bool get isEmpty => values.isEmpty;
}

class EpsInterval {
  const EpsInterval({
    required this.timeframe,
    this.levels,
    this.bias,
    this.liveTrade,
    this.history = const [],
  });

  /// '15m', '30m' or '1H'.
  final String timeframe;
  final EpsLevels? levels;
  final String? bias;

  /// The trade currently running on this timeframe; null between trades.
  final EpsTrade? liveTrade;

  /// Past finished trades, newest first.
  final List<EpsTrade> history;
}

class EpsSymbolSignals {
  const EpsSymbolSignals({required this.symbol, this.intervals = const []});

  /// 'NIFTY' or 'SENSEX'.
  final String symbol;
  final List<EpsInterval> intervals;
}

/// One poll of the EMA Pivot signals API.
class EpsFeed {
  const EpsFeed({this.symbols = const []});
  final List<EpsSymbolSignals> symbols;

  bool get isEmpty => symbols.every((s) => s.intervals.every((i) => i.liveTrade == null && i.history.isEmpty));
}
