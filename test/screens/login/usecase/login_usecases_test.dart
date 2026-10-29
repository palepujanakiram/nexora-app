import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/common/error/exceptions.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/send_code_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  Future<void> switchTo(ServerSession? s) async => switches.add(s?.phone);

  Matcher message(String text) => throwsA(isA<ServerApiException>().having((e) => e.message, 'message', text));

  setUp(() {
    server = FakeServerRepository();
    switches = [];
  });

  test('sends the code to the Indian number', () async {
    final sent = await SendCodeUseCase(server)(url: 'https://srv.test', mobile: '98765 43210');
    expect(sent.phone, '+919876543210');
    expect(sent.resendIn, const Duration(seconds: 30));
    expect(server.calls, ['requestCode https://srv.test +919876543210']);
  });

  test('checks the number before asking the server', () async {
    for (final mobile in ['', '12345', '98765abc10', '98765432101']) {
      await expectLater(SendCodeUseCase(server)(url: 'u', mobile: mobile), message('Enter your 10-digit mobile number.'));
    }
    await expectLater(
        SendCodeUseCase(server)(url: 'u', mobile: '1234567890'), message('Indian mobile numbers start with 6, 7, 8 or 9.'));
    expect(server.calls, isEmpty);
    expect(SendCodeUseCase.problemWith('98765 43210'), isNull);
  });

  test('signs in with the code, then wires the data to the server', () async {
    await SignInUseCase(server, switchTo)(url: 'https://srv.test', phone: '+919876543210', code: ' 123456 ');
    expect(server.calls, ['verifyCode https://srv.test +919876543210 123456']);
    expect(switches, ['+919876543210']);
  });

  test('checks the code shape, and a wrong code changes nothing', () async {
    final signIn = SignInUseCase(server, switchTo);
    await expectLater(signIn(url: 'u', phone: '+919876543210', code: '12a'), message('Enter the 6-digit code from the SMS.'));
    expect(server.calls, isEmpty);
    await expectLater(signIn(url: 'u', phone: '+919876543210', code: '000000'), message('Wrong code. 4 tries left.'));
    expect(switches, isEmpty);
  });

  test('the notice is why the last session ended', () {
    expect(GetSignInNoticeUseCase(server)(), isNull);
    server.expire('Your session ended. Sign in again.');
    expect(GetSignInNoticeUseCase(server)(), 'Your session ended. Sign in again.');
  });
}
