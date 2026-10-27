import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../../../common/domain/repositories/broker_repository.dart';

/// Exchanges the pasted redirect URL / request token / auth code for an
/// access token and stores it on the account.
class LoginWithRedirectUseCase {
  const LoginWithRedirectUseCase(this._brokers, this._accounts);

  final BrokerRepository _brokers;
  final AccountRepository _accounts;

  Future<void> call(BrokerAccount account, String redirectUrlOrCode) async {
    final token = await _brokers.exchangeToken(account, redirectUrlOrCode);
    await _accounts.save(account.copyWith(accessToken: token, tokenIssuedAt: DateTime.now()));
  }
}
