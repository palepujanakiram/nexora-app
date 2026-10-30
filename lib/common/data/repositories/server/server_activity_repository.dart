import '../../../domain/entities/execution_result.dart';
import '../../../domain/repositories/account_repository.dart';
import '../../../domain/repositories/activity_repository.dart';
import '../../../domain/repositories/refreshable.dart';
import '../../../utils/reactive_cache.dart';
import '../../datasources/local/preferences_datasource.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/server_order_model.dart';

/// The server's orders (`GET /orders`), shared by every device, one entry per
/// account. The server keeps every order for the audit trail, so **Clear**
/// only hides older ones on this device.
class ServerActivityRepository implements ActivityRepository, Refreshable {
  ServerActivityRepository(this._api, this._accounts, this._prefs);

  static const _limit = 200;
  static const _clearedKey = 'server_activity_cleared_at';

  final NexoraServerApi _api;
  final AccountRepository _accounts;
  final PreferencesDataSource _prefs;
  final _cache = ReactiveCache<List<ExecutionResult>>(const []);

  @override
  List<ExecutionResult> get current => _cache.value;

  @override
  Stream<List<ExecutionResult>> watch() => _cache.watch();

  @override
  Future<void> refresh() async {
    final json = await _api.get('/orders?limit=$_limit');
    final accounts = {for (final a in _accounts.current) a.id: a};
    final cleared = _clearedAt();
    _cache.value = List.unmodifiable([
      for (final order in (json['orders'] as List).cast<Map<String, dynamic>>())
        if (cleared == null || DateTime.parse(order['createdAt'] as String).isAfter(cleared))
          ...ServerOrderModel.fromOrder(order, accounts),
    ]);
  }

  /// The server already recorded these when it placed them; show them now.
  @override
  Future<void> addAll(List<ExecutionResult> results) async =>
      _cache.value = List.unmodifiable([...results, ...current].take(_limit));

  @override
  Future<void> clear() async {
    await _prefs.writeJson(_clearedKey, DateTime.now().toUtc().toIso8601String());
    _cache.value = const [];
  }

  DateTime? _clearedAt() {
    final raw = _prefs.readJson(_clearedKey);
    return raw is String ? DateTime.parse(raw) : null;
  }
}
