import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/accounts/usecase/check_broker_login_usecase.dart';

import '../../../fakes.dart';

void main() {
  test('asks the broker repository whether the account is logged in', () async {
    final brokers = FakeBrokerRepository()..loginChecks = [true];
    expect(await CheckBrokerLoginUseCase(brokers)(testAccount(id: 'x')), isTrue);
    expect(brokers.checked, ['x']);
  });
}
