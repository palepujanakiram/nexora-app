import '../../domain/entities/broker_account.dart';
import '../../domain/entities/execution_result.dart';

/// Maps the server's orders (`POST /orders`, `GET /orders`) to activity
/// entries: one [ExecutionResult] per leg, i.e. per account.
abstract final class ServerOrderModel {
  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  /// `NFO:CE:NIFTY:2026-10-29:2450000` → `NIFTY 29 OCT 2026 24500 CE`. Other
  /// ids are shown as they are.
  static String contractLabel(String instrumentId) {
    final p = instrumentId.split(':');
    final date = p.length == 5 ? DateTime.tryParse(p[3]) : null;
    final paise = p.length == 5 ? int.tryParse(p[4]) : null;
    if (date == null || paise == null || (p[1] != 'CE' && p[1] != 'PE')) return instrumentId;
    final strike = paise % 100 == 0 ? '${paise ~/ 100}' : (paise / 100).toStringAsFixed(2);
    final day = date.day.toString().padLeft(2, '0');
    return '${p[2]} $day ${_months[date.month - 1]} ${date.year} $strike ${p[1]}';
  }

  /// `PRODUCT` on the server for this app's product setting.
  static String product(ProductType p) => switch (p) {
    ProductType.carryForward => 'CARRYFORWARD',
    ProductType.intraday => 'INTRADAY',
  };

  /// A rupee amount as the server takes it: `"420.05"`.
  static String rupees(double v) => v.toStringAsFixed(2);

  /// One leg. [accounts] supplies the account's name; [signalText] is what the
  /// user pasted, when known (the server doesn't keep it).
  static ExecutionResult fromLeg(
    Map<String, dynamic> leg, {
    required Map<String, dynamic> order,
    required Map<String, BrokerAccount> accounts,
    required DateTime time,
    String? signalText,
  }) {
    final accountId = leg['accountId'] as String;
    final account = accounts[accountId];
    final status = leg['status'] as String? ?? 'UNKNOWN';
    final error = leg['error'];
    final errorMessage = error is Map ? error['message'] as String? : null;
    final instrument = order['instrumentId'] as String? ?? '';
    final symbol = contractLabel(instrument);
    final price = leg['price'] ?? order['price'];
    final quantity = (leg['quantity'] ?? order['quantity']) as int?;
    final exit = order['kind'] == 'EXIT';
    final paper = leg['mode'] == 'paper';
    final kind = '${exit ? 'EXIT' : 'ENTRY'}${paper ? ' (paper)' : ''} · ${statusLabel(status)}';
    final orderId = leg['brokerOrderId'] as String? ?? leg['legId'] as String? ?? '-';
    return ExecutionResult(
      accountLabel: account?.label ?? accountId,
      broker: account?.broker.label ?? BrokerType.values.asNameMap()[leg['broker']]?.label ?? '${leg['broker']}',
      signalText: signalText ?? '${order['side']} $quantity $symbol @ ${price ?? 'market'}',
      paper: paper,
      time: time,
      symbol: symbol,
      quantity: quantity,
      entryPrice: price == null ? null : double.tryParse('$price'),
      // A rejected leg reached no broker book; anything else has an order to show.
      orders: status == 'REJECTED' ? const [] : [PlacedOrder(kind, orderId)],
      error: status == 'REJECTED' ? errorMessage ?? 'Rejected.' : null,
      accountId: accountId,
      errorCode: error is Map ? error['code'] as String? : null,
    );
  }

  /// Every leg of an order from `GET /orders`, newest order first.
  static List<ExecutionResult> fromOrder(Map<String, dynamic> order, Map<String, BrokerAccount> accounts) {
    final time = DateTime.parse(order['createdAt'] as String).toLocal();
    return [
      for (final leg in (order['legs'] as List? ?? const []).cast<Map<String, dynamic>>())
        fromLeg(leg, order: order, accounts: accounts, time: time),
    ];
  }

  /// `PARTIALLY_FILLED` → `partially filled`; `UNKNOWN` says what happens next.
  static String statusLabel(String status) =>
      status == 'UNKNOWN' ? 'not confirmed yet, being checked' : status.toLowerCase().replaceAll('_', ' ');
}
