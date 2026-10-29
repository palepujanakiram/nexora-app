import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';
import 'package:nexora_app/screens/login/viewmodel/login_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  LoginViewModel build() {
    switches = [];
    return LoginViewModel(
      SignInUseCase(server, (s) async => switches.add(s?.email)),
      GetSignInNoticeUseCase(server),
    );
  }

  setUp(() => server = FakeServerRepository());

  test('signs in and ignores the invite code unless creating a login', () async {
    final vm = build();
    expect(vm.state.notice, isNull);
    final submit = vm.submit(url: 'https://srv.test', email: 'me@x.com', password: 'pw', inviteCode: 'stale');
    expect(vm.state.busy, isTrue);
    expect(await vm.submit(url: 'u', email: 'e', password: 'p'), isFalse, reason: 'busy');
    expect(await submit, isTrue);
    expect(vm.state.busy, isFalse);
    expect(server.calls, ['signIn https://srv.test me@x.com']);
    expect(switches, ['me@x.com']);
  });

  test('creates a login with the invite code', () async {
    final vm = build();
    var notified = 0;
    vm.addListener(() => notified++);
    vm.setCreating(true);
    expect(vm.state.creating, isTrue);
    expect(notified, 1);
    expect(await vm.submit(url: 'u', email: 'new@x.com', password: 'long enough', inviteCode: 'family'), isTrue);
    expect(server.calls, ['register u new@x.com family']);
  });

  test('shows the error, and clears it when switching mode', () async {
    final vm = build();
    server.failWith = 'Wrong email or password.';
    expect(await vm.submit(url: 'u', email: 'e', password: 'p'), isFalse);
    expect(vm.state.error, 'Wrong email or password.');
    expect(switches, isEmpty);
    vm.setCreating(true);
    expect(vm.state.error, isNull);
  });

  test('starts with why the last session ended', () {
    server.expire('Your session ended. Sign in again.');
    expect(build().state.notice, 'Your session ended. Sign in again.');
  });

  test('stops notifying after dispose', () async {
    final vm = build();
    final submit = vm.submit(url: 'u', email: 'e', password: 'p');
    vm.dispose();
    expect(await submit, isTrue); // finishing after dispose must not throw
  });
}
