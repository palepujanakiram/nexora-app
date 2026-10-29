import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  Future<void> switchTo(ServerSession? s) async => switches.add(s?.token);

  setUp(() {
    server = FakeServerRepository(const ServerSession(url: 'https://srv.test', token: 'tok', phone: '+919876543210'));
    switches = [];
  });

  test('sign out ends the session and unwires the server', () async {
    await SignOutUseCase(server, switchTo)();
    expect(server.calls, ['signOut']);
    expect(switches, [null]);
  });

  test('server IP and session changes come from the repository', () async {
    expect(await GetServerIpUseCase(server)(), '203.0.113.7');
    expect((await WatchServerUseCase(server)().first)?.phone, '+919876543210');
  });
}
