import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/execution_result.dart';
import '../../../domain/entities/trade_signal.dart';
import '../../../domain/repositories/signal_execution_repository.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/execution_result_model.dart';

/// Sends a signal to the nexora-backend server, which places it on each
/// account from its static IP and refuses repeats from other devices.
class ServerSignalExecutionRepository implements SignalExecutionRepository {
  ServerSignalExecutionRepository(this._api);

  final NexoraServerApi _api;

  @override
  Future<List<ExecutionResult>> execute(
    TradeSignal signal,
    Set<String> accountIds,
    AppSettings settings, {
    bool allowDuplicate = false,
  }) async {
    final json = await _api.post('/v1/signals/execute', {
      'text': signal.raw,
      'accountIds': accountIds.toList(),
      'settings': {
        'entryPriceMode': settings.entryPriceMode.name,
        'exitMode': settings.exitMode.name,
        'targetIndex': settings.targetIndex,
      },
      'allowDuplicate': allowDuplicate,
    });
    return [
      for (final raw in (json['results'] as List).cast<Map<String, dynamic>>()) ExecutionResultModel.fromJson(raw),
    ];
  }
}
