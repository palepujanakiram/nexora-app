import '../entities/broker_account.dart';

abstract interface class AccountRepository {
  List<BrokerAccount> get current;

  /// Emits the current accounts, then every change.
  Stream<List<BrokerAccount>> watch();

  /// Inserts or replaces by [BrokerAccount.id].
  Future<void> save(BrokerAccount account);

  Future<void> delete(String id);
}
