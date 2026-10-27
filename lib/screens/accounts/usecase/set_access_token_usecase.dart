import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/account_repository.dart';

/// Stores an access token the user generated elsewhere (e.g. the broker's
/// developer console).
class SetAccessTokenUseCase {
  const SetAccessTokenUseCase(this._accounts);

  final AccountRepository _accounts;

  Future<void> call(BrokerAccount account, String token) =>
      _accounts.save(account.copyWith(accessToken: token.trim(), tokenIssuedAt: DateTime.now()));
}
