import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/sign_in_code.dart';
import 'package:nexora_app/screens/login/model/login_state.dart';

void main() {
  const sent = SignInCode(phone: '+919876543210', expiresIn: Duration(minutes: 5), resendIn: Duration(seconds: 30));

  test('starts on the number step and moves to the code step once a code is sent', () {
    const start = LoginState(notice: 'ended');
    expect([start.enteringCode, start.sentTo, start.resendIn], [false, null, 0]);

    final code = start.copyWith(sent: sent, resendIn: 30, busy: true);
    expect([code.enteringCode, code.sentTo, code.resendIn, code.busy, code.notice],
        [true, '+91 98765 43210', 30, true, 'ended']);
    expect(code.copyWith(clearSent: true).enteringCode, isFalse);
    expect(start.copyWith(needsInvite: true).copyWith(busy: true).needsInvite, isTrue);
  });

  test('keeps the error until cleared', () {
    final s = const LoginState().copyWith(error: 'bad');
    expect(s.copyWith(busy: true).error, 'bad');
    expect(s.copyWith(clearError: true).error, isNull);
  });
}
