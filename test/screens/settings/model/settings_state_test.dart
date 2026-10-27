import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/entities/proxy_health.dart';
import 'package:nexora_app/screens/settings/model/settings_state.dart';

void main() {
  SettingsState withHealth(ProxyHealth h) => SettingsState(proxyHealth: h);

  test('defaults', () {
    const s = SettingsState();
    expect(s.isWeb, isFalse);
    expect(s.testingProxy, isFalse);
    expect(s.proxyHealth, isNull);
    expect(s.proxyTestMessage, isNull);
    expect(s.proxyTestPassed, isFalse);
    expect(s.showTargetPicker, isTrue);
    expect(SettingsState.targetChoices, [0, 1, 2]);
  });

  test('target picker only shows with GTT exits', () {
    expect(const SettingsState(settings: AppSettings(exitMode: ExitMode.entryOnly)).showTargetPicker, isFalse);
    expect(const SettingsState(settings: AppSettings(exitMode: ExitMode.withStopAndTarget)).showTargetPicker, isTrue);
  });

  group('proxyTestMessage', () {
    test('connected with orders blocked', () {
      final s = withHealth(const ProxyHealth(ProxyHealthStatus.connected));
      expect(s.proxyTestPassed, isTrue);
      expect(s.proxyTestMessage, 'Connected. Order placement is blocked on this proxy (safe for paper trading).');
    });

    test('connected with orders enabled', () {
      final s = withHealth(const ProxyHealth(ProxyHealthStatus.connected, ordersEnabled: true));
      expect(s.proxyTestPassed, isTrue);
      expect(s.proxyTestMessage, 'Connected. Orders are ENABLED on this proxy.');
    });

    test('origin not allowed names the origin', () {
      final s = withHealth(const ProxyHealth(ProxyHealthStatus.originNotAllowed, origin: 'http://localhost:1234'));
      expect(s.proxyTestPassed, isFalse);
      expect(
        s.proxyTestMessage,
        "The proxy is running but doesn't accept this app's address (http://localhost:1234). "
        "Add it to ALLOWED_ORIGINS in the Worker's variables.",
      );
    });

    test('origin not allowed without a reported origin', () {
      final s = withHealth(const ProxyHealth(ProxyHealthStatus.originNotAllowed));
      expect(s.proxyTestMessage, contains('(unknown)'));
    });

    test('not a proxy', () {
      final s = withHealth(const ProxyHealth(ProxyHealthStatus.notAProxy));
      expect(s.proxyTestPassed, isFalse);
      expect(s.proxyTestMessage, "Something answered at that URL, but it isn't the NexoraApp proxy code.");
    });

    test('unreachable', () {
      final s = withHealth(const ProxyHealth(ProxyHealthStatus.unreachable));
      expect(s.proxyTestPassed, isFalse);
      expect(s.proxyTestMessage, startsWith("Couldn't reach the proxy."));
    });
  });

  test('copyWith keeps isWeb and can clear the proxy health', () {
    const h = ProxyHealth(ProxyHealthStatus.notAProxy);
    const s = SettingsState(isWeb: true, testingProxy: true, proxyHealth: h);

    final kept = s.copyWith();
    expect(kept.isWeb, isTrue);
    expect(kept.testingProxy, isTrue);
    expect(kept.proxyHealth, same(h));

    final changed = s.copyWith(settings: const AppSettings(targetIndex: 2), testingProxy: false, clearProxyHealth: true);
    expect(changed.isWeb, isTrue);
    expect(changed.settings.targetIndex, 2);
    expect(changed.testingProxy, isFalse);
    expect(changed.proxyHealth, isNull);

    const other = ProxyHealth(ProxyHealthStatus.connected);
    expect(s.copyWith(proxyHealth: other).proxyHealth, same(other));
  });
}
