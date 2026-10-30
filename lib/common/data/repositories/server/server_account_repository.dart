import '../../../domain/entities/broker_account.dart';
import '../../../domain/repositories/account_repository.dart';
import '../../../domain/repositories/refreshable.dart';
import '../../../error/exceptions.dart';
import '../../../utils/reactive_cache.dart';
import '../../datasources/local/preferences_datasource.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/server_account_model.dart';

/// Broker accounts stored on the nexora-backend server, cached here so the
/// screens can read them synchronously. Lots, product, "use by default" and
/// the Upstox redirect URI are kept on this device ([ServerAccountModel]).
class ServerAccountRepository implements AccountRepository, Refreshable {
  ServerAccountRepository(this._api, this._prefs);

  static const _localKey = 'server_account_settings_v1';

  final NexoraServerApi _api;
  final PreferencesDataSource _prefs;
  final _cache = ReactiveCache<List<BrokerAccount>>(const []);

  @override
  List<BrokerAccount> get current => _cache.value;

  @override
  Stream<List<BrokerAccount>> watch() => _cache.watch();

  @override
  Future<void> refresh() async {
    final json = await _api.get('/broker-accounts');
    _cache.value = List.unmodifiable([
      for (final raw in (json['accounts'] as List).cast<Map<String, dynamic>>()) ?_fromServer(raw),
    ]);
  }

  /// Creates the account, or applies what changed. The server stores only the
  /// mode of an existing account; other changes stay on this device (and the
  /// placeholder token after a login only updates this cache).
  @override
  Future<void> save(BrokerAccount account) async {
    final before = current.where((a) => a.id == account.id).firstOrNull;
    if (before == null) {
      final json = await _api.post('/broker-accounts', ServerAccountModel.toCreateJson(account));
      final created = json['account'] as Map<String, dynamic>;
      await _saveLocal(created['id'] as String, account);
      _put(_fromServer(created)!);
      return;
    }
    final fixed = ServerAccountModel.unchangeable(before, account);
    if (fixed != null) {
      throw ServerApiException('The server can\'t change an account\'s $fixed. Delete the account and add it again.');
    }
    await _saveLocal(account.id, account);
    if (account.paperMode == before.paperMode) {
      _put(account);
      return;
    }
    _put(
      _fromServer(await _api.patch('/broker-accounts/${account.id}', {'mode': account.paperMode ? 'paper' : 'live'}))!,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete('/broker-accounts/$id');
    final local = _local()..remove(id);
    await _prefs.writeJson(_localKey, local);
    _cache.value = List.unmodifiable(current.where((a) => a.id != id));
  }

  /// Applies an account the server returned from another call (e.g. a login).
  void putFromServer(Map<String, dynamic> json) {
    final account = _fromServer(json);
    if (account != null) _put(account);
  }

  BrokerAccount? _fromServer(Map<String, dynamic> json) {
    final local = _local()[json['id']];
    return ServerAccountModel.fromJson(json, local is Map<String, dynamic> ? local : null);
  }

  Map<String, dynamic> _local() {
    final raw = _prefs.readJson(_localKey);
    return raw is Map<String, dynamic> ? {...raw} : {};
  }

  Future<void> _saveLocal(String id, BrokerAccount account) =>
      _prefs.writeJson(_localKey, {..._local(), id: ServerAccountModel.localJson(account)});

  void _put(BrokerAccount account) {
    final next = [...current];
    final i = next.indexWhere((a) => a.id == account.id);
    if (i >= 0) {
      next[i] = account;
    } else {
      next.add(account);
    }
    _cache.value = List.unmodifiable(next);
  }
}
