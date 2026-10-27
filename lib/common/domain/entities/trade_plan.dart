import 'broker_account.dart';
import 'trade_signal.dart';

/// A broker contract resolved from a signal.
class ResolvedInstrument {
  const ResolvedInstrument({
    required this.symbol,
    required this.exchange,
    required this.lotSize,
    this.instrumentKey,
    this.tickSize = 0.05,
  });

  /// Human-readable trading symbol (Kite `tradingsymbol`).
  final String symbol;
  final String exchange;
  final int lotSize;

  /// Upstox `instrument_key`; unused for Kite.
  final String? instrumentKey;
  final double tickSize;
}

/// What to send for one account: an entry limit order and, optionally, a
/// stop loss / target pair the broker manages server-side.
class TradePlan {
  const TradePlan({
    required this.signal,
    required this.quantity,
    required this.entryPrice,
    required this.product,
    this.stopLoss,
    this.target,
  });

  final TradeSignal signal;
  final int quantity;
  final double entryPrice;
  final ProductType product;
  final double? stopLoss;
  final double? target;

  bool get hasExits => stopLoss != null && target != null;
}
