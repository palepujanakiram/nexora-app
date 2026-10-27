import '../../../domain/entities/execution_result.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../domain/repositories/refreshable.dart';
import '../../../utils/reactive_cache.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/execution_result_model.dart';

/// The activity log on the nexora-backend server, shared by every device.
class ServerActivityRepository implements ActivityRepository, Refreshable {
  ServerActivityRepository(this._api);

  static const _limit = 200;

  final NexoraServerApi _api;
  final _cache = ReactiveCache<List<ExecutionResult>>(const []);

  @override
  List<ExecutionResult> get current => _cache.value;

  @override
  Stream<List<ExecutionResult>> watch() => _cache.watch();

  @override
  Future<void> refresh() async {
    final json = await _api.get('/v1/activity?limit=$_limit');
    _cache.value = List.unmodifiable([
      for (final raw in (json['results'] as List).cast<Map<String, dynamic>>()) ExecutionResultModel.fromJson(raw),
    ]);
  }

  /// The server already recorded these when it placed them; show them now.
  @override
  Future<void> addAll(List<ExecutionResult> results) async =>
      _cache.value = List.unmodifiable([...results, ...current].take(_limit));

  @override
  Future<void> clear() async {
    await _api.delete('/v1/activity');
    _cache.value = const [];
  }
}
