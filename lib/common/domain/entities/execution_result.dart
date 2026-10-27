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

  /// Set by the server for some errors: `duplicate` (already placed recently)
  /// or `in_flight` (being placed from another device right now).
  final String? errorCode;

  bool get success => error == null;

  /// Refused because the same signal was already placed on this account
  /// recently. It can be sent again on purpose ("Place anyway").
  bool get isDuplicate => errorCode == 'duplicate';
}
