import '../../domain/entities/execution_result.dart';

/// JSON mapping for [ExecutionResult] and [PlacedOrder].
abstract final class ExecutionResultModel {
  static Map<String, dynamic> toJson(ExecutionResult r) => {
        'accountLabel': r.accountLabel,
        'broker': r.broker,
        'signalText': r.signalText,
        'paper': r.paper,
        'time': r.time.toIso8601String(),
        'symbol': r.symbol,
        'quantity': r.quantity,
        'entryPrice': r.entryPrice,
        'orders': [for (final o in r.orders) {'kind': o.kind, 'id': o.id}],
        'error': r.error,
        'accountId': r.accountId,
        'errorCode': r.errorCode,
      };

  static ExecutionResult fromJson(Map<String, dynamic> j) => ExecutionResult(
        accountLabel: j['accountLabel'] as String,
        broker: j['broker'] as String,
        signalText: j['signalText'] as String,
        paper: j['paper'] as bool,
        // The server sends UTC; show it in the device's time zone.
        time: DateTime.parse(j['time'] as String).toLocal(),
        symbol: j['symbol'] as String?,
        quantity: j['quantity'] as int?,
        entryPrice: (j['entryPrice'] as num?)?.toDouble(),
        orders: [
          for (final o in (j['orders'] as List? ?? []).cast<Map>())
            PlacedOrder(o['kind'] as String, o['id'] as String),
        ],
        error: j['error'] as String?,
        accountId: j['accountId'] as String?,
        errorCode: j['errorCode'] as String?,
      );
}
