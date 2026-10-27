import '../../../common/domain/repositories/account_repository.dart';

/// Removes an account and its stored keys from this device.
class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._accounts);

  final AccountRepository _accounts;

  Future<void> call(String accountId) => _accounts.delete(accountId);
}
