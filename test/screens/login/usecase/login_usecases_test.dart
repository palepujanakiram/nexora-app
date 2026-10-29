import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/common/error/exceptions.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  Future<void> switchTo(ServerSession? s) async => switches.add(s?.email);

  setUp(() {
    server = FakeServerRepository();
    switches = [];
  });

  test('signs in, then wires the data to the server', () async {
    await SignInUseCase(server, switchTo)(url: 'https://srv.test', email: 'me@x.com', password: 'pw');
    expect(server.calls, ['signIn https://srv.test me@x.com']);
    expect(switches, ['me@x.com']);
  });

  test('with an invite code creates a login; a blank code just signs in', () async {
    await SignInUseCase(server, switchTo)(url: 'u', email: 'new@x.com', password: 'pw', inviteCode: ' code ');
    await SignInUseCase(server, switchTo)(url: 'u', email: 'me@x.com', password: 'pw', inviteCode: '  ');
    expect(server.calls, ['register u new@x.com code', 'signIn u me@x.com']);
  });

  test('a failed sign-in leaves the data where it was', () async {
    server.failWith = 'Wrong email or password.';
    await expectLater(SignInUseCase(server, switchTo)(url: 'u', email: 'e', password: 'p'),
        throwsA(isA<ServerApiException>()));
    expect(switches, isEmpty);
  });

  test('the notice is why the last session ended on its own', () {
    expect(GetSignInNoticeUseCase(server)(), isNull);
    server.expire();
    expect(GetSignInNoticeUseCase(server)(), 'Your session ended. Sign in again.');
  });
}
