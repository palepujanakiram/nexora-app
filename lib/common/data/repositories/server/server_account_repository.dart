import '../../../domain/entities/broker_account.dart';
import '../../../domain/repositories/account_repository.dart';
import '../../../domain/repositories/refreshable.dart';
import '../../../utils/reactive_cache.dart';
import '../../datasources/remote/nexora_server_api.dart';
import '../../models/server_account_model.dart';

/// Broker accounts stored on the nexora-backend server, cached here so the
/// screens can read them synchronously.
class ServerAccountRepository implements AccountRepository, Refreshable {
  ServerAccountRepository(this._api);

  final NexoraServerApi _api;
  final _cache = ReactiveCache<List<BrokerAccount>>(const []);
  final _loginUrls = <String, String>{};

  @override
  List<BrokerAccount> get current => _cache.value;

  @override
  Stream<List<BrokerAccount>> watch() => _cache.watch();

  /// The broker login page for [accountId], as the server last described it.
  String loginUrlFor(String accountId) => _loginUrls[accountId] ?? '';

  @override
  Future<void> refresh() async {
    final json = await _api.get('/v1/accounts');
    _loginUrls.clear();
    final accounts = [
      for (final raw in (json['accounts'] as List).cast<Map<String, dynamic>>()) _remember(raw),
    ];
    _cache.value = List.unmodifiable(accounts);
  }

  /// Creates the account, or sends what changed. Changes the server doesn't
  /// store (the placeholder token after a login) only update this cache.
  @override
  Future<void> save(BrokerAccount account) async {
    final before = current.where((a) => a.id == account.id).firstOrNull;
    if (before == null) {
      _put(_remember(await _api.post('/v1/accounts', ServerAccountModel.toCreateJson(account))));
      return;
    }
    final patch = ServerAccountModel.toPatchJson(before, account);
    _put(patch.isEmpty ? account : _remember(await _api.patch('/v1/accounts/${account.id}', patch)));
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete('/v1/accounts/$id');
    _loginUrls.remove(id);
    _cache.value = List.unmodifiable(current.where((a) => a.id != id));
  }

  /// Applies an account the server returned from another call (e.g. a login).
  void putFromServer(Map<String, dynamic> json) => _put(_remember(json));

  BrokerAccount _remember(Map<String, dynamic> json) {
    final account = ServerAccountModel.fromJson(json);
    _loginUrls[account.id] = ServerAccountModel.loginUrl(json);
    return account;
  }

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
