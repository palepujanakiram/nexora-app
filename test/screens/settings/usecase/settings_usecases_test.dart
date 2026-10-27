import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/proxy_health.dart';
import 'package:nexora_app/screens/settings/usecase/get_proxy_worker_script_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/test_proxy_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/update_settings_usecase.dart';

import '../../../fakes.dart';
import '../fake_proxy_repository.dart';

void main() {
  test('UpdateSettingsUseCase applies the change to the current settings and saves', () async {
    final repo = FakeSettingsRepository(const AppSettings(targetIndex: 2, corsProxy: 'https://p'));
    await UpdateSettingsUseCase(repo)((s) => s.copyWith(themeColor: ThemeColor.blue));
    expect(repo.current.themeColor, ThemeColor.blue);
    expect(repo.current.targetIndex, 2);
    expect(repo.current.corsProxy, 'https://p');
  });

  test('GetProxyWorkerScriptUseCase returns the worker source', () async {
    final repo = FakeProxyRepository(script: 'export default {}');
    expect(await GetProxyWorkerScriptUseCase(repo)(), 'export default {}');
  });

  test('TestProxyUseCase checks the given URL', () async {
    final repo = FakeProxyRepository(health: const ProxyHealth(ProxyHealthStatus.unreachable));
    final h = await TestProxyUseCase(repo)('https://proxy.example');
    expect(h.status, ProxyHealthStatus.unreachable);
    expect(repo.checked, ['https://proxy.example']);
  });
}
