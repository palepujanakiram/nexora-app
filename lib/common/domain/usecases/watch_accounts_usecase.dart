import '../entities/broker_account.dart';
import '../repositories/account_repository.dart';

/// Shared by the Signal and Accounts screens.
class WatchAccountsUseCase {
  const WatchAccountsUseCase(this._accounts);

  final AccountRepository _accounts;

  Stream<List<BrokerAccount>> call() => _accounts.watch();
}
