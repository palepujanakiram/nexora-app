import '../entities/app_settings.dart';
import '../entities/execution_result.dart';
import '../entities/trade_signal.dart';

/// Places a signal somewhere other than this device: the nexora-backend
/// server, which also records the orders in the shared activity log. It
/// places the entry only: no stop loss or target orders.
abstract interface class SignalExecutionRepository {
  Future<List<ExecutionResult>> execute(TradeSignal signal, Set<String> accountIds, AppSettings settings);
}
