import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/broker_repository.dart';

class GetLoginUrlUseCase {
  const GetLoginUrlUseCase(this._brokers);

  final BrokerRepository _brokers;

  Future<String> call(BrokerAccount account) => _brokers.loginUrl(account);

  /// Whether the dialog may offer "It is an access token".
  bool get acceptsAccessTokens => _brokers.acceptsAccessTokens;
}
