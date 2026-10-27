import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/proxy_health.dart';
import 'package:nexora_app/common/domain/usecases/watch_settings_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_proxy_worker_script_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/test_proxy_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/update_settings_usecase.dart';
import 'package:nexora_app/screens/settings/viewmodel/settings_viewmodel.dart';

import '../../../fakes.dart';
import '../fake_proxy_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeProxyRepository proxy;
  late SettingsViewModel vm;

  setUp(() async {
    settings = FakeSettingsRepository(const AppSettings(corsProxy: 'https://old'));
    proxy = FakeProxyRepository(script: 'export default {}');
    vm = SettingsViewModel(
      WatchSettingsUseCase(settings),
      UpdateSettingsUseCase(settings),
      GetProxyWorkerScriptUseCase(proxy),
      TestProxyUseCase(proxy),
    );
    await pumpEventQueue();
  });

  tearDown(() => vm.dispose());

  test('starts from the stored settings, not on web in VM tests', () {
    expect(vm.state.settings.corsProxy, 'https://old');
    expect(vm.state.isWeb, isFalse);
    expect(vm.state.testingProxy, isFalse);
    expect(vm.state.proxyHealth, isNull);
  });

  test('setters save and the state follows the repository', () async {
    await vm.setThemeColor(ThemeColor.purple);
    await vm.setEntryPriceMode(EntryPriceMode.low);
    await vm.setExitMode(ExitMode.entryOnly);
    await vm.setTargetIndex(2);
    await pumpEventQueue();

    expect(settings.current.themeColor, ThemeColor.purple);
    expect(settings.current.entryPriceMode, EntryPriceMode.low);
    expect(settings.current.exitMode, ExitMode.entryOnly);
    expect(settings.current.targetIndex, 2);
    expect(vm.state.settings.themeColor, ThemeColor.purple);
    expect(vm.state.settings.targetIndex, 2);
    expect(vm.state.showTargetPicker, isFalse);
  });

  test('setCorsProxy trims, saves and clears an old test result', () async {
    await vm.testProxy('https://old');
    expect(vm.state.proxyHealth, isNotNull);

    await vm.setCorsProxy('  https://new  ');
    await pumpEventQueue();
    expect(settings.current.corsProxy, 'https://new');
    expect(vm.state.settings.corsProxy, 'https://new');
    expect(vm.state.proxyHealth, isNull);
  });

  test('setCorsProxy with the same value does nothing', () async {
    await vm.testProxy('https://old');
    var notified = 0;
    vm.addListener(() => notified++);
    await vm.setCorsProxy(' https://old ');
    expect(notified, 0);
    expect(vm.state.proxyHealth, isNotNull);
  });

  test('testProxy saves the URL, reports progress, then the result', () async {
    proxy
      ..health = const ProxyHealth(ProxyHealthStatus.originNotAllowed, origin: 'http://localhost:1')
      ..gate = Completer<void>();

    final running = vm.testProxy('https://p.example');
    await pumpEventQueue();
    expect(vm.state.testingProxy, isTrue);
    expect(vm.state.proxyHealth, isNull);
    expect(settings.current.corsProxy, 'https://p.example');
    expect(proxy.checked, ['https://p.example']);

    proxy.gate!.complete();
    await running;
    expect(vm.state.testingProxy, isFalse);
    expect(vm.state.proxyHealth?.status, ProxyHealthStatus.originNotAllowed);
    expect(vm.state.proxyTestPassed, isFalse);
    expect(vm.state.proxyTestMessage, contains('http://localhost:1'));
  });

  test('workerScript loads the bundled worker', () async {
    expect(await vm.workerScript(), 'export default {}');
  });

  test('dispose stops listening to settings', () async {
    final other = SettingsViewModel(
      WatchSettingsUseCase(settings),
      UpdateSettingsUseCase(settings),
      GetProxyWorkerScriptUseCase(proxy),
      TestProxyUseCase(proxy),
    );
    await pumpEventQueue();
    other.dispose();
    await settings.save(const AppSettings(targetIndex: 1));
    await pumpEventQueue();
    expect(other.state.settings.targetIndex, 0);
  });
}
