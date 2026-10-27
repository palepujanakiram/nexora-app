import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/accounts/usecase/get_login_url_usecase.dart';

import '../../../fakes.dart';

void main() {
  test('returns the broker login URL for the account', () {
    expect(GetLoginUrlUseCase(FakeBrokerRepository())(testAccount(id: 'x')), 'https://login.example/x');
  });
}
