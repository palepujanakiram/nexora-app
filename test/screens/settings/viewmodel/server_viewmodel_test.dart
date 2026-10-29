import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';
import 'package:nexora_app/screens/settings/viewmodel/server_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  const session = ServerSession(url: 'https://srv.test', token: 'tok', phone: '+919876543210');

  ServerViewModel build({ServerSession? initial = session, Future<void> Function(ServerSession?)? switchTo}) {
    server = FakeServerRepository(initial);
    return ServerViewModel(
      WatchServerUseCase(server),
      SignOutUseCase(server, switchTo ?? (_) async {}),
      GetServerIpUseCase(server),
    );
  }

  test('follows the session: look up the IP, then sign out', () async {
    final vm = build();
    await pumpEventQueue();
    expect(vm.state.session?.phone, '+919876543210');

    final ip = vm.loadServerIp();
    expect(vm.state.loadingIp, isTrue);
    await ip;
    expect(vm.state.serverIp, '203.0.113.7');

    expect(await vm.signOut(), isTrue);
    await pumpEventQueue();
    expect(vm.state.connected, isFalse);
    expect(vm.state.serverIp, isNull);
    expect(vm.state.busy, isFalse);
    vm.dispose();
  });

  test('shows errors, clears them, and ignores a second sign-out while busy', () async {
    final vm = build(switchTo: (_) async => throw StateError('Couldn\'t switch.'));
    final first = vm.signOut();
    expect(await vm.signOut(), isFalse, reason: 'busy');
    expect(await first, isFalse);
    expect(vm.state.error, 'Bad state: Couldn\'t switch.');
    vm.clearError();
    expect(vm.state.error, isNull);

    server.failWith = 'Couldn\'t reach the server.';
    await vm.loadServerIp();
    expect(vm.state.error, 'Couldn\'t reach the server.');
    expect(vm.state.loadingIp, isFalse);
    vm.dispose();
  });

  test('stops notifying after dispose', () async {
    final vm = build();
    vm.dispose();
    await server.signOut(); // emits after dispose: must not throw
    await pumpEventQueue();
  });
}
