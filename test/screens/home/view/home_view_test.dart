import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/proxy_health.dart';
import 'package:nexora_app/common/domain/repositories/proxy_repository.dart';
import 'package:nexora_app/common/domain/services/signal_parser.dart';
import 'package:nexora_app/common/domain/usecases/watch_accounts_usecase.dart';
import 'package:nexora_app/common/domain/usecases/watch_settings_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/toggle_account_enabled_usecase.dart';
import 'package:nexora_app/screens/accounts/view/accounts_view.dart';
import 'package:nexora_app/screens/activity/usecase/clear_activity_usecase.dart';
import 'package:nexora_app/screens/activity/usecase/watch_activity_usecase.dart';
import 'package:nexora_app/screens/activity/view/activity_view.dart';
import 'package:nexora_app/screens/home/model/home_tab.dart';
import 'package:nexora_app/screens/home/view/home_view.dart';
import 'package:nexora_app/common/domain/usecases/sync_from_server_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/change_password_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_proxy_worker_script_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/test_proxy_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/update_settings_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';
import 'package:nexora_app/screens/settings/view/settings_view.dart';
import 'package:nexora_app/screens/signal/usecase/execute_signal_usecase.dart';
import 'package:nexora_app/screens/signal/usecase/parse_signal_usecase.dart';
import 'package:nexora_app/screens/signal/view/signal_view.dart';

import 'package:nexora_app/common/domain/repositories/refreshable.dart';
import 'package:nexora_app/common/presentation/widgets/info_banner.dart';
import 'package:nexora_app/screens/signal/viewmodel/signal_viewmodel.dart';
import 'package:provider/provider.dart';

import '../../../fakes.dart';

class _Flaky implements Refreshable {
  String? error;
  var calls = 0;

  @override
  Future<void> refresh() async {
    calls++;
    if (error != null) throw Exception(error);
  }
}

class _FakeProxyRepository implements ProxyRepository {
  @override
  Future<String> workerScript() async => '// worker';

  @override
  Future<ProxyHealth> check(String proxyUrl) async => const ProxyHealth(ProxyHealthStatus.unreachable);
}

void main() {
  setUp(() {
    final accounts = FakeAccountRepository([testAccount()]);
    final settings = FakeSettingsRepository();
    final activity = FakeActivityRepository();
    final broker = FakeBrokerRepository();
    final proxy = _FakeProxyRepository();
    final server = FakeServerRepository();
    Future<void> noSwitch(_) async {}
    sl
      ..reset()
      ..registerFactory(() => SyncFromServerUseCase([accounts, activity]))
      ..registerFactory(() => WatchServerUseCase(server))
      ..registerFactory(() => SignOutUseCase(server, noSwitch))
      ..registerFactory(() => ChangePasswordUseCase(server, noSwitch))
      ..registerFactory(() => GetServerIpUseCase(server))
      ..registerFactory(() => WatchAccountsUseCase(accounts))
      ..registerFactory(() => WatchSettingsUseCase(settings))
      ..registerFactory(() => ParseSignalUseCase(SignalParser()))
      ..registerFactory(() => ExecuteSignalUseCase(broker, accounts, settings, activity))
      ..registerFactory(() => ToggleAccountEnabledUseCase(accounts))
      ..registerFactory(() => WatchActivityUseCase(activity))
      ..registerFactory(() => ClearActivityUseCase(activity))
      ..registerFactory(() => UpdateSettingsUseCase(settings))
      ..registerFactory(() => GetProxyWorkerScriptUseCase(proxy))
      ..registerFactory(() => TestProxyUseCase(proxy));
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomeView()));
    await tester.pumpAndSettle();
  }

  int stackIndex(WidgetTester tester) => tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;

  testWidgets('builds all four tabs and starts on Signal', (tester) async {
    await pumpView(tester);

    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.selectedIndex, 0);
    expect(nav.destinations, hasLength(4));
    for (final t in HomeTab.values) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(t.label)), findsOneWidget);
    }
    expect(stackIndex(tester), 0);
    expect(find.byType(SignalView), findsOneWidget);
    expect(find.byType(AccountsView, skipOffstage: false), findsOneWidget);
    expect(find.byType(ActivityView, skipOffstage: false), findsOneWidget);
    expect(find.byType(SettingsView, skipOffstage: false), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget, reason: 'selected icon for Signal');
  });

  testWidgets('tapping destinations switches the visible tab', (tester) async {
    await pumpView(tester);
    Finder dest(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

    await tester.tap(dest('Accounts'));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 1);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(find.text('Broker accounts'), findsOneWidget);
    expect(find.byIcon(Icons.key), findsOneWidget);

    await tester.tap(dest('Activity'));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 2);
    expect(find.text('Executed signals will appear here.'), findsOneWidget);

    await tester.tap(dest('Settings'));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 3);
    expect(find.byIcon(Icons.tune), findsOneWidget);

    await tester.tap(dest('Signal'));
    await tester.pumpAndSettle();
    expect(stackIndex(tester), 0);
    expect(find.text('Broker accounts'), findsNothing);
  });

  testWidgets('shows a failed server sync with Retry, and clears it once it works', (tester) async {
    final flaky = _Flaky()..error = 'offline';
    sl
      ..unregister<SyncFromServerUseCase>()
      ..registerFactory(() => SyncFromServerUseCase([flaky]));
    await pumpView(tester);
    expect(find.text('Couldn\'t load from the server: Exception: offline'), findsOneWidget);

    flaky.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(InfoBanner), findsNothing);
    expect(flaky.calls, 2);
  });

  testWidgets('switching where the data lives rebuilds the screens and syncs', (tester) async {
    final flaky = _Flaky();
    sl
      ..unregister<SyncFromServerUseCase>()
      ..registerFactory(() => SyncFromServerUseCase([flaky]));
    await pumpView(tester);
    final before = Provider.of<SignalViewModel>(tester.element(find.byType(ListView).first), listen: false);

    dataGeneration.value++;
    await tester.pumpAndSettle();
    final after = Provider.of<SignalViewModel>(tester.element(find.byType(ListView).first), listen: false);
    expect(identical(before, after), isFalse, reason: 'view models are rebuilt on the new repositories');
    expect(flaky.calls, 2);
  });
}
