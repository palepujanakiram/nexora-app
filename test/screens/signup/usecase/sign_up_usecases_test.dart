import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/common/domain/entities/sign_up_details.dart';
import 'package:nexora_app/common/error/exceptions.dart';
import 'package:nexora_app/screens/signup/usecase/send_sign_up_code_usecase.dart';
import 'package:nexora_app/screens/signup/usecase/sign_up_usecase.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  Future<void> switchTo(ServerSession? s) async => switches.add(s?.phone);

  Matcher message(String text) => throwsA(isA<ServerApiException>().having((e) => e.message, 'message', text));

  const ravi = SignUpDetails(
    fullName: 'Ravi Kumar',
    email: 'ravi@example.com',
    acceptsTerms: true,
    acceptsRisk: true,
    acceptsDataUse: true,
  );

  SignUpDetails ravis({String fullName = 'Ravi Kumar', String email = 'ravi@example.com', bool risk = true}) =>
      SignUpDetails(fullName: fullName, email: email, acceptsTerms: true, acceptsRisk: risk, acceptsDataUse: true);

  setUp(() {
    server = FakeServerRepository();
    switches = [];
  });

  test('sends a sign-up code for the form to the Indian number', () async {
    final sent = await SendSignUpCodeUseCase(server)(url: 'https://srv.test', mobile: '98765 43210', details: ravi);
    expect(sent.phone, '+919876543210');
    expect(server.calls, ['requestSignUpCode https://srv.test +919876543210 Ravi Kumar ravi@example.com']);
  });

  test('checks the form before asking the server, in the order of the fields', () async {
    final send = SendSignUpCodeUseCase(server);
    await expectLater(send(url: 'u', mobile: '', details: ravis(fullName: '')), message('Enter your full name.'));
    await expectLater(send(url: 'u', mobile: '12345', details: ravi), message('Enter your 10-digit mobile number.'));
    await expectLater(
        send(url: 'u', mobile: '9876543210', details: ravis(email: 'ravi')), message('Enter a valid email address.'));
    await expectLater(
        send(url: 'u', mobile: '9876543210', details: ravis(risk: false)), message(SendSignUpCodeUseCase.confirmEach));
    expect(SendSignUpCodeUseCase.confirmEach, 'Please confirm each of the statements to create your account.');
    expect(server.calls, isEmpty);
  });

  test('creates the account with the code, then wires the data to the server', () async {
    await SignUpUseCase(server, switchTo)(url: 'https://srv.test', phone: '+919876543210', details: ravi, code: ' 123456 ');
    expect(server.calls, ['verifySignUp https://srv.test +919876543210 Ravi Kumar ravi@example.com 123456']);
    expect(switches, ['+919876543210']);
  });

  test('checks the code is six digits, and passes on the server\'s refusals', () async {
    final signUp = SignUpUseCase(server, switchTo);
    for (final code in ['', '12345', '1234567', 'abcdef']) {
      await expectLater(signUp(url: 'u', phone: '+919876543210', details: ravi, code: code),
          message('Enter the 6-digit code from the SMS.'));
    }
    expect(server.calls, isEmpty);

    server.registeredPhones.add('+919876543210');
    await expectLater(
      signUp(url: 'u', phone: '+919876543210', details: ravi, code: '123456'),
      throwsA(isA<ServerApiException>().having((e) => e.code, 'code', SignUpUseCase.alreadyRegistered)),
    );
    expect(switches, isEmpty);
    expect([SignUpUseCase.alreadyRegistered, SignUpUseCase.emailTaken], ['already_registered', 'conflict']);
  });
}
