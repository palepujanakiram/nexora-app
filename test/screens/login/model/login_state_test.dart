import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/login/model/login_state.dart';

void main() {
  test('copyWith keeps the notice and clears the error on request', () {
    const s = LoginState(notice: 'ended', error: 'bad');
    final next = s.copyWith(creating: true, busy: true);
    expect([next.creating, next.busy, next.error, next.notice], [true, true, 'bad', 'ended']);
    expect(next.copyWith(clearError: true).error, isNull);
    expect(const LoginState().copyWith(error: 'x').error, 'x');
  });
}
