import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/accounts/model/login_state.dart';

void main() {
  const base = LoginState(loginUrl: 'https://x', codeName: 'code');

  test('defaults to not busy without an error', () {
    expect(base.busy, isFalse);
    expect(base.error, isNull);
  });

  test('copyWith keeps url and code name and updates busy/error', () {
    final s = base.copyWith(busy: true, error: 'boom');
    expect(s.loginUrl, 'https://x');
    expect(s.codeName, 'code');
    expect(s.busy, isTrue);
    expect(s.error, 'boom');

    final kept = s.copyWith();
    expect(kept.busy, isTrue);
    expect(kept.error, 'boom');

    final cleared = s.copyWith(busy: false, clearError: true);
    expect(cleared.busy, isFalse);
    expect(cleared.error, isNull);
  });
}
