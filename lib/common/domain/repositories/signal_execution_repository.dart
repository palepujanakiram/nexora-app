import '../entities/app_settings.dart';
import '../entities/execution_result.dart';
import '../entities/trade_signal.dart';

/// Places a signal somewhere other than this device: the nexora-backend
/// server, which also records the results in the shared activity log.
abstract interface class SignalExecutionRepository {
  /// [allowDuplicate] places it even if the server saw the same signal on an
  /// account in the last few minutes (e.g. from another device).
  Future<List<ExecutionResult>> execute(
    TradeSignal signal,
    Set<String> accountIds,
    AppSettings settings, {
    bool allowDuplicate = false,
  });
}
