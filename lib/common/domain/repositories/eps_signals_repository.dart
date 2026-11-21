import '../entities/eps_signal.dart';

/// Live NIFTY/SENSEX trade signals from Nexora's EMA Pivot rule, read
/// through a proxy that keeps the vendor's API key server-side.
abstract interface class EpsSignalsRepository {
  /// [symbols] and [timeframes] default to the measured-profitable set the
  /// vendor recommends (both symbols, 15m/30m/1H — never 3m/5m or option
  /// premium signals, which the vendor's own testing shows lose money).
  Future<EpsFeed> fetchSignals({
    List<String> symbols = const ['NIFTY', 'SENSEX'],
    List<String> timeframes = const ['15m', '30m', '1H'],
    int history = 5,
  });
}
