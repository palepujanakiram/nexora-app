import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/signup/model/sign_up_consent.dart';
import 'package:nexora_app/screens/signup/usecase/send_sign_up_code_usecase.dart';
import 'package:nexora_app/screens/signup/usecase/sign_up_usecase.dart';
import 'package:nexora_app/screens/signup/viewmodel/sign_up_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  SignUpViewModel build() {
    server = FakeServerRepository();
    switches = [];
    return SignUpViewModel(
      SendSignUpCodeUseCase(server),
      SignUpUseCase(server, (ServerSession? s) async => switches.add(s?.phone)),
    );
  }

  void confirmAll(SignUpViewModel vm) {
    for (final c in SignUpConsent.values) {
      vm.confirm(c, true);
    }
  }

  Future<bool> send(SignUpViewModel vm, {String email = 'ravi@example.com'}) =>
      vm.sendCode(url: 'https://srv.test', mobile: '9876543210', fullName: 'Ravi Kumar', email: email);

  test('ticks and unticks statements', () {
    final vm = build();
    vm.confirm(SignUpConsent.risk, true);
    vm.confirm(SignUpConsent.terms, true);
    expect(vm.state.confirmed, {SignUpConsent.risk, SignUpConsent.terms});
    vm.confirm(SignUpConsent.risk, false);
    expect(vm.state.confirmed, {SignUpConsent.terms});
    vm.dispose();
  });

  test('asks for every statement before sending anything', () async {
    final vm = build();
    vm.confirm(SignUpConsent.terms, true);
    expect(await send(vm), isFalse);
    expect(vm.state.error, SendSignUpCodeUseCase.confirmEach);
    expect(vm.state.enteringCode, isFalse);
    expect(server.calls, isEmpty);
    vm.dispose();
  });

  test('sends the form, then creates the account with the code', () async {
    final vm = build();
    expect(await vm.verify('123456'), isFalse, reason: 'no code sent yet');
    confirmAll(vm);
    expect(await send(vm), isTrue);
    expect([vm.state.enteringCode, vm.state.sentTo, vm.state.resendIn], [true, '+91 98765 43210', 30]);

    expect(await vm.verify('000000'), isFalse);
    expect(vm.state.error, 'Wrong code. 4 tries left.');
    expect(vm.state.alreadyRegistered, isFalse);
    expect(await vm.verify('123456'), isTrue);
    expect(vm.state.error, isNull);
    expect(server.calls.last, 'verifySignUp https://srv.test +919876543210 Ravi Kumar ravi@example.com 123456');
    expect(switches, ['+919876543210']);
    vm.dispose();
  });

  test('offers to sign in when the number already has an account', () async {
    final vm = build();
    confirmAll(vm);
    await send(vm);
    server.registeredPhones.add('+919876543210');
    expect(await vm.verify('123456'), isFalse);
    expect(vm.state.alreadyRegistered, isTrue);
    expect(vm.state.error, 'This mobile number already has an account. Sign in instead.');
    expect(vm.state.enteringCode, isTrue);
    expect(switches, isEmpty);
    vm.dispose();
  });

  test('goes back to the form when the email belongs to another account', () async {
    final vm = build();
    confirmAll(vm);
    await send(vm, email: 'taken@example.com');
    server.registeredEmails.add('taken@example.com');
    expect(await vm.verify('123456'), isFalse);
    expect(vm.state.enteringCode, isFalse);
    expect(vm.state.error, 'An account with this email already exists.');
    expect(vm.state.confirmed, hasLength(3), reason: 'the ticks are kept');

    expect(await send(vm, email: 'ravi@example.com'), isTrue);
    expect(await vm.verify('123456'), isTrue);
    vm.dispose();
  });

  testWidgets('counts down to resend, sends the same form again, and can go back to edit it', (tester) async {
    final vm = build();
    confirmAll(vm);
    await send(vm);
    expect(await vm.resend(), isFalse, reason: 'still waiting');
    await tester.pump(const Duration(seconds: 30));
    expect(vm.state.resendIn, 0);
    expect(await vm.resend(), isTrue);
    expect(server.calls.where((c) => c.startsWith('requestSignUpCode https://srv.test +919876543210 Ravi Kumar')),
        hasLength(2));

    await vm.verify('000000');
    vm.editDetails();
    expect([vm.state.enteringCode, vm.state.error, vm.state.resendIn], [false, null, 0]);
    vm.dispose();
    await tester.pump(const Duration(seconds: 5)); // the timer is gone: no notify after dispose
  });

  test('ignores a second request while one is running, and a wait of zero starts no countdown', () async {
    final vm = build();
    confirmAll(vm);
    server.resendIn = Duration.zero;
    server.hold = Completer<void>();
    final first = send(vm);
    expect(vm.state.busy, isTrue);
    expect(await send(vm), isFalse);
    server.hold!.complete();
    expect(await first, isTrue);
    expect(vm.state.resendIn, 0);
    expect(server.calls, hasLength(1));
    vm.dispose();
  });
}
