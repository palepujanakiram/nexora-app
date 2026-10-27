import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/account_repository.dart';

/// Sets whether an account is pre-selected when executing signals.
class ToggleAccountEnabledUseCase {
  const ToggleAccountEnabledUseCase(this._accounts);

  final AccountRepository _accounts;

  Future<void> call(BrokerAccount account, bool enabled) => _accounts.save(account.copyWith(enabled: enabled));
}
