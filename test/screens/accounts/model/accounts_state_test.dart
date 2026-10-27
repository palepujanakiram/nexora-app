import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/accounts/model/accounts_state.dart';

import '../../../fakes.dart';

void main() {
  test('empty by default with no groups', () {
    const s = AccountsState();
    expect(s.isEmpty, isTrue);
    expect(s.groups, isEmpty);
  });

  test('groups accounts by broker in BrokerType order and skips empty brokers', () {
    final up = testAccount(id: 'u').copyWith(broker: BrokerType.upstox);
    final z1 = testAccount(id: 'z1');
    final z2 = testAccount(id: 'z2');
    final s = AccountsState(accounts: [up, z1, z2]);

    expect(s.isEmpty, isFalse);
    final groups = s.groups;
    expect(groups.map((g) => g.$1), [BrokerType.zerodha, BrokerType.upstox]);
    expect(groups[0].$2.map((a) => a.id), ['z1', 'z2']);
    expect(groups[1].$2.map((a) => a.id), ['u']);

    final onlyUpstox = AccountsState(accounts: [up]).groups;
    expect(onlyUpstox.single.$1, BrokerType.upstox);
  });
}
