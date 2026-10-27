import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/accounts/usecase/login_with_redirect_usecase.dart';

import '../../../fakes.dart';

class _FailingBroker extends FakeBrokerRepository {
  @override
  Future<String> exchangeToken(BrokerAccount account, String input) async => throw Exception('bad code');
}

void main() {
  test('exchanges the redirect for a token and saves it with a fresh issue time', () async {
    final account = testAccount(loggedIn: false);
    final accounts = FakeAccountRepository([account]);
    final before = DateTime.now();

    await LoginWithRedirectUseCase(FakeBrokerRepository(), accounts)(account, 'abc');

    final saved = accounts.current.single;
    expect(saved.accessToken, 'token-abc');
    expect(saved.tokenIssuedAt!.isBefore(before), isFalse);
    expect(saved.hasValidToken, isTrue);
  });

  test('does not save anything when the exchange fails', () async {
    final account = testAccount(loggedIn: false);
    final accounts = FakeAccountRepository([account]);

    await expectLater(LoginWithRedirectUseCase(_FailingBroker(), accounts)(account, 'abc'), throwsException);
    expect(accounts.current.single.accessToken, isNull);
  });
}
