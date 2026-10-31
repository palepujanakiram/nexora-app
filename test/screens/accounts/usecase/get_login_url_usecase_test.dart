import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/accounts/usecase/get_login_url_usecase.dart';

import '../../../fakes.dart';

void main() {
  test('returns the broker login URL for the account', () async {
    expect(await GetLoginUrlUseCase(FakeBrokerRepository())(testAccount(id: 'x')), 'https://login.example/x');
  });

  test('says whether the user may paste an access token', () {
    final brokers = FakeBrokerRepository();
    expect(GetLoginUrlUseCase(brokers).acceptsAccessTokens, isTrue);
    brokers.acceptsAccessTokens = false;
    expect(GetLoginUrlUseCase(brokers).acceptsAccessTokens, isFalse);
  });

  test('says whether the server finishes the login', () {
    final brokers = FakeBrokerRepository();
    expect(GetLoginUrlUseCase(brokers).loginFinishesOnServer, isFalse);
    brokers.loginFinishesOnServer = true;
    expect(GetLoginUrlUseCase(brokers).loginFinishesOnServer, isTrue);
  });
}
