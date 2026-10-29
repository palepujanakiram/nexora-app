import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/usecase/change_password_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';
import 'package:nexora_app/screens/settings/viewmodel/server_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  const session = ServerSession(url: 'https://srv.test', token: 'tok', email: 'me@x.com');

  ServerViewModel build([ServerSession? initial = session]) {
    server = FakeServerRepository(initial);
    Future<void> noSwitch(_) async {}
    return ServerViewModel(
      WatchServerUseCase(server),
      SignOutUseCase(server, noSwitch),
      ChangePasswordUseCase(server, noSwitch),
      GetServerIpUseCase(server),
    );
  }

  test('follows the session: look up the IP, change the password, sign out', () async {
    final vm = build();
    await pumpEventQueue();
    expect(vm.state.session?.email, 'me@x.com');

    final ip = vm.loadServerIp();
    expect(vm.state.loadingIp, isTrue);
    await ip;
    expect(vm.state.serverIp, '203.0.113.7');

    expect(await vm.changePassword(currentPassword: 'old password', newPassword: 'new password'), isTrue);
    await pumpEventQueue();
    expect(vm.state.session?.token, 'tok2');
    expect(vm.state.busy, isFalse);

    expect(await vm.signOut(), isTrue);
    await pumpEventQueue();
    expect(vm.state.connected, isFalse);
    expect(vm.state.serverIp, isNull);
    vm.dispose();
  });

  test('shows errors, clears them, and ignores a second request while busy', () async {
    final vm = build();
    server.failWith = 'Current password is wrong.';
    final first = vm.changePassword(currentPassword: 'x', newPassword: 'new password');
    expect(await vm.signOut(), isFalse, reason: 'busy');
    expect(await first, isFalse);
    expect(vm.state.error, 'Current password is wrong.');
    vm.clearError();
    expect(vm.state.error, isNull);

    await vm.loadServerIp();
    expect(vm.state.error, 'Current password is wrong.');
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
