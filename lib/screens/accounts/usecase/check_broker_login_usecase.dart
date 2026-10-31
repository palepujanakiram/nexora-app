import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/broker_repository.dart';

/// Whether an account's broker login has finished, e.g. on the server after
/// the user signed in on the broker's page.
class CheckBrokerLoginUseCase {
  const CheckBrokerLoginUseCase(this._brokers);

  final BrokerRepository _brokers;

  Future<bool> call(BrokerAccount account) => _brokers.checkLoggedIn(account);
}
