import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/broker_repository.dart';

class GetLoginUrlUseCase {
  const GetLoginUrlUseCase(this._brokers);

  final BrokerRepository _brokers;

  String call(BrokerAccount account) => _brokers.loginUrl(account);
}
