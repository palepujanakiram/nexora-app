import '../../../common/domain/entities/app_settings.dart';
import '../../../common/domain/entities/proxy_health.dart';

class SettingsState {
  const SettingsState({
    this.settings = const AppSettings(),
    this.isWeb = false,
    this.testingProxy = false,
    this.proxyHealth,
  });

  final AppSettings settings;

  /// The CORS proxy only matters on web.
  final bool isWeb;

  final bool testingProxy;

  /// Result of the last "Test proxy"; null until tested.
  final ProxyHealth? proxyHealth;

  bool get showTargetPicker => settings.exitMode == ExitMode.withStopAndTarget;

  static const targetChoices = [0, 1, 2];

  bool get proxyTestPassed => proxyHealth?.status == ProxyHealthStatus.connected;

  String? get proxyTestMessage {
    final h = proxyHealth;
    if (h == null) return null;
    return switch (h.status) {
      ProxyHealthStatus.connected => h.ordersEnabled
          ? 'Connected. Orders are ENABLED on this proxy.'
          : 'Connected. Order placement is blocked on this proxy (safe for paper trading).',
      ProxyHealthStatus.originNotAllowed =>
        'The proxy is running but doesn\'t accept this app\'s address (${h.origin ?? 'unknown'}). '
            'Add it to ALLOWED_ORIGINS in the Worker\'s variables.',
      ProxyHealthStatus.notAProxy => 'Something answered at that URL, but it isn\'t the NexoraApp proxy code.',
      ProxyHealthStatus.unreachable =>
        'Couldn\'t reach the proxy. Check the URL and that the Worker is deployed with the NexoraApp code.',
    };
  }

  SettingsState copyWith({
    AppSettings? settings,
    bool? testingProxy,
    ProxyHealth? proxyHealth,
    bool clearProxyHealth = false,
  }) =>
      SettingsState(
        settings: settings ?? this.settings,
        isWeb: isWeb,
        testingProxy: testingProxy ?? this.testingProxy,
        proxyHealth: clearProxyHealth ? null : proxyHealth ?? this.proxyHealth,
      );
}
