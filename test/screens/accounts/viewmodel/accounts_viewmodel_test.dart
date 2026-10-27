import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/usecases/watch_accounts_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/toggle_account_enabled_usecase.dart';
import 'package:nexora_app/screens/accounts/viewmodel/accounts_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  test('mirrors the account stream and toggles enabled', () async {
    final accounts = FakeAccountRepository([testAccount(id: 'a')]);
    final vm = AccountsViewModel(WatchAccountsUseCase(accounts), ToggleAccountEnabledUseCase(accounts));
    var notified = 0;
    vm.addListener(() => notified++);

    expect(vm.state.isEmpty, isTrue);
    await pumpEventQueue();
    expect(vm.state.accounts.map((a) => a.id), ['a']);

    await vm.setEnabled(accounts.current.single, false);
    await pumpEventQueue();
    expect(vm.state.accounts.single.enabled, isFalse);
    expect(notified, greaterThanOrEqualTo(1));

    vm.dispose();
    final before = notified;
    await accounts.save(testAccount(id: 'b'));
    await pumpEventQueue();
    expect(notified, before, reason: 'no updates after dispose');
  });
}
