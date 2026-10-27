import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/accounts/usecase/toggle_account_enabled_usecase.dart';

import '../../../fakes.dart';

void main() {
  test('saves the account with the new enabled flag', () async {
    final account = testAccount(enabled: true);
    final accounts = FakeAccountRepository([account]);
    final toggle = ToggleAccountEnabledUseCase(accounts);

    await toggle(account, false);
    expect(accounts.current.single.enabled, isFalse);

    await toggle(accounts.current.single, true);
    expect(accounts.current.single.enabled, isTrue);
  });
}
