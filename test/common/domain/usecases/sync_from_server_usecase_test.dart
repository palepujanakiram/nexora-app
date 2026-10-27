import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/repositories/refreshable.dart';
import 'package:nexora_app/common/domain/usecases/sync_from_server_usecase.dart';
import 'package:nexora_app/common/error/exceptions.dart';

import '../../../fakes.dart';

class _Refreshable implements Refreshable {
  _Refreshable([this.error]);
  final Object? error;
  var refreshed = 0;

  @override
  Future<void> refresh() async {
    refreshed++;
    if (error != null) throw error!;
  }
}

void main() {
  test('refreshes every server-backed repository and ignores local ones', () async {
    final a = _Refreshable();
    final b = _Refreshable();
    expect(await SyncFromServerUseCase([a, FakeAccountRepository(), b])(), isNull);
    expect([a.refreshed, b.refreshed], [1, 1]);
  });

  test('does nothing when the app works on its own', () async {
    expect(await SyncFromServerUseCase([FakeAccountRepository(), FakeActivityRepository()])(), isNull);
  });

  test('returns why it failed', () async {
    final failing = _Refreshable(ServerApiException('Couldn\'t reach the server'));
    expect(await SyncFromServerUseCase([failing])(), 'Couldn\'t reach the server');
  });
}
