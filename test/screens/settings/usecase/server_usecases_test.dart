import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/common/error/exceptions.dart';
import 'package:nexora_app/screens/settings/usecase/change_password_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  Future<void> switchTo(ServerSession? s) async => switches.add(s?.token);

  setUp(() {
    server = FakeServerRepository(const ServerSession(url: 'https://srv.test', token: 'tok', email: 'me@x.com'));
    switches = [];
  });

  test('sign out ends the session and unwires the server', () async {
    await SignOutUseCase(server, switchTo)();
    expect(server.calls, ['signOut']);
    expect(switches, [null]);
  });

  test('change password moves the data to the new session', () async {
    await ChangePasswordUseCase(server, switchTo)(currentPassword: 'old password', newPassword: 'new password');
    expect(server.calls, ['changePassword old password new password']);
    expect(switches, ['tok2']);
  });

  test('change password checks the new password before asking the server', () async {
    final change = ChangePasswordUseCase(server, switchTo);
    await expectLater(change(currentPassword: 'old', newPassword: 'short'),
        throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('at least 10'))));
    await expectLater(change(currentPassword: 'same password', newPassword: 'same password'),
        throwsA(isA<ServerApiException>().having((e) => e.message, 'message', contains('differs'))));
    expect(server.calls, isEmpty);
  });

  test('a refused change keeps the current session', () async {
    server.failWith = 'Current password is wrong.';
    await expectLater(ChangePasswordUseCase(server, switchTo)(currentPassword: 'x', newPassword: 'new password'),
        throwsA(isA<ServerApiException>()));
    expect(switches, isEmpty);
  });

  test('server IP and session changes come from the repository', () async {
    expect(await GetServerIpUseCase(server)(), '203.0.113.7');
    expect((await WatchServerUseCase(server)().first)?.email, 'me@x.com');
  });
}
