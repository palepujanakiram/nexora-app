import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/send_code_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';
import 'package:nexora_app/screens/login/viewmodel/login_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  LoginViewModel build() {
    server = FakeServerRepository();
    switches = [];
    return LoginViewModel(
      SendCodeUseCase(server),
      SignInUseCase(server, (ServerSession? s) async => switches.add(s?.token)),
      GetSignInNoticeUseCase(server),
    );
  }

  test('sends the code, then signs in with it', () async {
    final vm = build();
    expect(vm.state.enteringCode, isFalse);
    expect(await vm.verify('123456'), isFalse, reason: 'no code sent yet');

    expect(await vm.sendCode(url: 'https://srv.test', mobile: '9876543210'), isTrue);
    expect(vm.state.enteringCode, isTrue);
    expect(vm.state.sentTo, '+91 98765 43210');
    expect(vm.state.resendIn, 30);

    expect(await vm.verify('000000'), isFalse);
    expect(vm.state.error, 'Wrong code. 4 tries left.');
    expect(await vm.verify('123456'), isTrue);
    expect(vm.state.error, isNull);
    expect(server.calls.last, 'verifyCode https://srv.test +919876543210 123456');
    expect(switches, ['tok']);
    vm.dispose();
  });

  // testWidgets runs timers on a fake clock that tester.pump moves forward.
  testWidgets('counts down to resend, then sends again to the same number', (tester) async {
    final vm = build();
    await vm.sendCode(url: 'u', mobile: '9876543210');
    expect(await vm.resend(), isFalse, reason: 'still waiting');

    await tester.pump(const Duration(seconds: 29));
    expect(vm.state.resendIn, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(vm.state.resendIn, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(vm.state.resendIn, 0, reason: 'the countdown stopped');

    expect(await vm.resend(), isTrue);
    expect(server.calls, ['requestCode u +919876543210', 'requestCode u +919876543210']);
    expect(vm.state.resendIn, 30);
    vm.dispose();
    await tester.pump(const Duration(seconds: 5)); // the timer is gone: no notify after dispose
  });

  testWidgets('changing the number goes back to the first step', (tester) async {
    final vm = build();
    await vm.sendCode(url: 'u', mobile: '9876543210');
    vm.changeNumber();
    expect([vm.state.enteringCode, vm.state.resendIn, vm.state.error], [false, 0, null]);
    await tester.pump(const Duration(seconds: 5));
    expect(vm.state.resendIn, 0, reason: 'the countdown stopped');
    vm.dispose();
  });

  test('shows send errors, ignores a second request while busy, and starts with the notice', () async {
    final vm = build();
    server.failWith = "This number isn't allowed to sign in.";
    final first = vm.sendCode(url: 'u', mobile: '9876543210');
    expect(await vm.sendCode(url: 'u', mobile: '9876543210'), isFalse, reason: 'busy');
    expect(await first, isFalse);
    expect(vm.state.error, "This number isn't allowed to sign in.");
    expect(vm.state.enteringCode, isFalse);
    vm.dispose();

    final fresh = build();
    server.expire('Your session ended. Sign in again.');
    final noticed = LoginViewModel(SendCodeUseCase(server), SignInUseCase(server, (_) async {}), GetSignInNoticeUseCase(server));
    expect(noticed.state.notice, 'Your session ended. Sign in again.');
    fresh.dispose();
    noticed.dispose();
  });

  test('says the user is not found when the number has no login', () async {
    final vm = build();
    server.unknownPhones.add('+919030863940');
    expect(await vm.sendCode(url: 'u', mobile: '9030863940'), isFalse);
    expect(vm.state.error, 'User not found.');
    expect(vm.state.enteringCode, isFalse);
    vm.dispose();
  });

  test('a code with no wait does not start a countdown', () async {
    final vm = build();
    server.resendIn = Duration.zero;
    await vm.sendCode(url: 'u', mobile: '9876543210');
    expect(vm.state.resendIn, 0);
    expect(await vm.resend(), isTrue);
    vm.dispose();
  });
}
