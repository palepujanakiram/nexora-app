class PlacedOrder {
  const PlacedOrder(this.kind, this.id);

  /// e.g. "ENTRY", "GTT OCO".
  final String kind;
  final String id;
}

/// Outcome of executing one signal on one account.
class ExecutionResult {
  const ExecutionResult({
    required this.accountLabel,
    required this.broker,
    required this.signalText,
    required this.paper,
    required this.time,
    this.symbol,
    this.quantity,
    this.entryPrice,
    this.orders = const [],
    this.error,
    this.accountId,
    this.errorCode,
  });

  final String accountLabel;
  final String broker;
  final String signalText;
  final bool paper;
  final DateTime time;
  final String? symbol;
  final int? quantity;
  final double? entryPrice;
  final List<PlacedOrder> orders;
  final String? error;

  /// The account it ran on; null for entries saved by older versions.
  final String? accountId;

  /// The server's error code, e.g. `INSUFFICIENT_FUNDS` on a rejected leg or
  /// `market_closed` when a risk check refused the order.
  final String? errorCode;

  bool get success => error == null;
}
