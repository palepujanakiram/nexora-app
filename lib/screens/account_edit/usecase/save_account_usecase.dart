import 'package:uuid/uuid.dart';

import '../../../common/domain/entities/broker_account.dart';
import '../../../common/domain/repositories/account_repository.dart';
import '../model/account_form.dart';

/// Creates a new account or updates [existing] from a validated form.
class SaveAccountUseCase {
  const SaveAccountUseCase(this._accounts);

  final AccountRepository _accounts;

  Future<BrokerAccount> call(AccountForm form, {BrokerAccount? existing}) async {
    final apiKey = form.apiKey.trim();
    // A token belongs to one API key; drop it if the key or broker changed.
    final keepToken = existing != null && existing.apiKey == apiKey && existing.broker == form.broker;
    final account = BrokerAccount(
      id: existing?.id ?? const Uuid().v4(),
      broker: form.broker,
      label: form.label.trim(),
      apiKey: apiKey,
      apiSecret: form.apiSecret.trim(),
      redirectUri: form.redirectUri.trim(),
      accessToken: keepToken ? existing.accessToken : null,
      tokenIssuedAt: keepToken ? existing.tokenIssuedAt : null,
      enabled: existing?.enabled ?? true,
      lots: int.parse(form.lots.trim()),
      product: form.product,
      paperMode: form.paperMode,
    );
    await _accounts.save(account);
    return account;
  }
}
