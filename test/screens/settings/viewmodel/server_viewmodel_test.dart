import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/usecase/connect_server_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/disconnect_server_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';
import 'package:nexora_app/screens/settings/viewmodel/server_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;

  ServerViewModel build([ServerSession? initial]) {
    server = FakeServerRepository(initial);
    Future<void> noSwitch(_) async {}
    return ServerViewModel(
      WatchServerUseCase(server),
      ConnectServerUseCase(server, noSwitch),
      DisconnectServerUseCase(server, noSwitch),
      GetServerIpUseCase(server),
    );
  }

  test('follows the session: connect, look up the IP, disconnect', () async {
    final vm = build();
    await pumpEventQueue();
    expect(vm.state.connected, isFalse);

    expect(await vm.connect(url: 'https://srv.test', email: 'me@x.com', password: 'pw'), isTrue);
    await pumpEventQueue();
    expect(vm.state.session?.email, 'me@x.com');
    expect(vm.state.busy, isFalse);

    final ip = vm.loadServerIp();
    expect(vm.state.loadingIp, isTrue);
    await ip;
    expect(vm.state.serverIp, '203.0.113.7');

    expect(await vm.disconnect(), isTrue);
    await pumpEventQueue();
    expect(vm.state.connected, isFalse);
    expect(vm.state.serverIp, isNull);
    vm.dispose();
  });

  test('shows errors, clears them, and ignores a second request while busy', () async {
    final vm = build();
    server.failWith = 'Wrong invite code.';
    final first = vm.connect(url: 'u', email: 'e', password: 'p', inviteCode: 'x');
    expect(await vm.connect(url: 'u', email: 'e', password: 'p'), isFalse, reason: 'busy');
    expect(await first, isFalse);
    expect(vm.state.error, 'Wrong invite code.');
    vm.clearError();
    expect(vm.state.error, isNull);

    await vm.loadServerIp();
    expect(vm.state.error, 'Wrong invite code.');
    expect(vm.state.loadingIp, isFalse);
    vm.dispose();
  });

  test('stops notifying after dispose', () async {
    final vm = build(const ServerSession(url: 'u', token: 't', email: 'e'));
    vm.dispose();
    await server.signOut(); // emits after dispose: must not throw
    await pumpEventQueue();
  });
}
