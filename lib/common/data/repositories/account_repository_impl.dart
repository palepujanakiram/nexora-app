import '../../domain/entities/broker_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../utils/reactive_cache.dart';
import '../datasources/local/secure_storage_datasource.dart';
import '../models/broker_account_model.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl._(this._storage, List<BrokerAccount> initial) : _cache = ReactiveCache(initial);

  static const _key = 'broker_accounts_v1';

  final SecureStorageDataSource _storage;
  final ReactiveCache<List<BrokerAccount>> _cache;

  static Future<AccountRepositoryImpl> load(SecureStorageDataSource storage) async {
    final raw = await storage.readJson(_key) as List? ?? const [];
    final accounts = [for (final e in raw) BrokerAccountModel.fromJson(Map<String, dynamic>.from(e as Map))];
    return AccountRepositoryImpl._(storage, accounts);
  }

  @override
  List<BrokerAccount> get current => _cache.value;

  @override
  Stream<List<BrokerAccount>> watch() => _cache.watch();

  @override
  Future<void> save(BrokerAccount account) {
    final next = [...current];
    final i = next.indexWhere((a) => a.id == account.id);
    if (i >= 0) {
      next[i] = account;
    } else {
      next.add(account);
    }
    return _persist(next);
  }

  @override
  Future<void> delete(String id) => _persist(current.where((a) => a.id != id).toList());

  Future<void> _persist(List<BrokerAccount> accounts) {
    _cache.value = List.unmodifiable(accounts);
    return _storage.writeJson(_key, [for (final a in accounts) BrokerAccountModel.toJson(a)]);
  }
}
