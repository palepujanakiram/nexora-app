import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/accounts/usecase/set_access_token_usecase.dart';

import '../../../fakes.dart';

void main() {
  test('stores the trimmed token and marks it as issued now', () async {
    final account = testAccount(loggedIn: false);
    final accounts = FakeAccountRepository([account]);

    await SetAccessTokenUseCase(accounts)(account, '  tok123 \n');

    final saved = accounts.current.single;
    expect(saved.accessToken, 'tok123');
    expect(saved.hasValidToken, isTrue);
  });
}
