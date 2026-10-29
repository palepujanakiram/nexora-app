import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/usecases/watch_settings_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_proxy_worker_script_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/test_proxy_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/update_settings_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';
import 'package:nexora_app/screens/settings/view/settings_view.dart';
import 'package:nexora_app/screens/settings/view/widgets/cors_proxy_help.dart';
import 'package:nexora_app/screens/settings/view/widgets/theme_color_picker.dart';

import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/view/widgets/server_section.dart';

import '../../../fakes.dart';
import '../fake_proxy_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late FakeProxyRepository proxy;
  late FakeServerRepository server;

  Future<void> register([AppSettings initial = const AppSettings()]) async {
    settings = FakeSettingsRepository(initial);
    proxy = FakeProxyRepository();
    server = FakeServerRepository();
    await sl.reset();
    Future<void> noSwitch(_) async {}
    sl
      ..registerFactory(() => WatchServerUseCase(server))
      ..registerFactory(() => SignOutUseCase(server, noSwitch))
      ..registerFactory(() => GetServerIpUseCase(server))
      ..registerFactory(() => WatchSettingsUseCase(settings))
      ..registerFactory(() => UpdateSettingsUseCase(settings))
      ..registerFactory(() => GetProxyWorkerScriptUseCase(proxy))
      ..registerFactory(() => TestProxyUseCase(proxy));
  }

  setUp(register);

  Future<void> pumpView(WidgetTester tester, {bool isWeb = false}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SettingsView(key: UniqueKey(), isWeb: isWeb))));
    await tester.pumpAndSettle();
  }

  String proxyText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('shows the stored settings (mobile layout)', (tester) async {
    await pumpView(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme colour'), findsOneWidget);
    expect(tester.widget<ThemeColorPicker>(find.byType(ThemeColorPicker)).selected, ThemeColor.green);
    expect(tester.widget<SegmentedButton<EntryPriceMode>>(find.byType(SegmentedButton<EntryPriceMode>)).selected,
        {EntryPriceMode.high});
    for (final m in EntryPriceMode.values) {
      expect(find.text(m.label), findsOneWidget);
    }
    expect(find.byType(RadioListTile<ExitMode>), findsNWidgets(ExitMode.values.length));
    expect(find.text('Target used for the GTT exit'), findsOneWidget);
    expect(find.text('Falls back to the last target if the signal has fewer.'), findsOneWidget);
    expect(tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>)).selected, {0});
    expect(find.text('Web CORS proxy'), findsOneWidget);
    expect(find.text('Not needed on iOS/Android — leave empty.'), findsOneWidget);
    // Web-only parts are hidden off the web.
    expect(find.text('Test proxy'), findsNothing);
    expect(find.byType(CorsProxyHelp), findsNothing);
  });

  testWidgets('theme, entry price and target choices are saved', (tester) async {
    await pumpView(tester);

    await tester.tap(find.byTooltip('Purple'));
    await tester.pumpAndSettle();
    expect(settings.current.themeColor, ThemeColor.purple);
    expect(tester.widget<ThemeColorPicker>(find.byType(ThemeColorPicker)).selected, ThemeColor.purple);

    await tester.tap(find.text('Middle'));
    await tester.pumpAndSettle();
    expect(settings.current.entryPriceMode, EntryPriceMode.mid);

    await tester.tap(find.text('TGT3'));
    await tester.pumpAndSettle();
    expect(settings.current.targetIndex, 2);
    expect(tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>)).selected, {2});
  });

  testWidgets('entry-only exits hide the target picker', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Entry order only'));
    await tester.pumpAndSettle();
    expect(settings.current.exitMode, ExitMode.entryOnly);
    expect(find.text('Target used for the GTT exit'), findsNothing);
    expect(find.byType(SegmentedButton<int>), findsNothing);

    await tester.tap(find.text(ExitMode.withStopAndTarget.label));
    await tester.pumpAndSettle();
    expect(settings.current.exitMode, ExitMode.withStopAndTarget);
    expect(find.text('Target used for the GTT exit'), findsOneWidget);
  });

  testWidgets('proxy URL is saved trimmed on submit', (tester) async {
    await pumpView(tester);
    await tester.enterText(find.byType(TextField), '  https://p.example  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(settings.current.corsProxy, 'https://p.example');
  });

  testWidgets('proxy URL is saved when tapping outside the field', (tester) async {
    await pumpView(tester);
    await tester.enterText(find.byType(TextField), 'https://q.example');
    await tester.pump();
    expect(settings.current.corsProxy, '');
    await tester.tapAt(tester.getCenter(find.text('Settings')));
    await tester.pumpAndSettle();
    expect(settings.current.corsProxy, 'https://q.example');
  });

  testWidgets(
    'the field starts with the stored proxy URL',
    (tester) async {
      await register(const AppSettings(corsProxy: 'https://saved.example'));
      await pumpView(tester);
      // Focusing the field and tapping elsewhere must not wipe the stored URL.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.text('Settings')));
      await tester.pumpAndSettle();
      expect(settings.current.corsProxy, 'https://saved.example');
      expect(proxyText(tester), 'https://saved.example');
    },
  );

  testWidgets('the field follows a proxy URL saved elsewhere', (tester) async {
    await pumpView(tester);
    await settings.save(const AppSettings(corsProxy: 'https://other.example'));
    await tester.pumpAndSettle();
    expect(proxyText(tester), 'https://other.example');
  });

  testWidgets('web layout shows the proxy test and the setup guide', (tester) async {
    await pumpView(tester, isWeb: true);
    expect(find.text('Browsers block direct calls to broker APIs, so the web app needs your own proxy.'),
        findsOneWidget);
    expect(find.byType(CorsProxyHelp), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'https://w.example');
    await tester.tap(find.text('Test proxy'));
    await tester.pumpAndSettle();
    expect(proxy.checked, ['https://w.example']);
    expect(settings.current.corsProxy, 'https://w.example');
    expect(find.text('Connected. Order placement is blocked on this proxy (safe for paper trading).'),
        findsOneWidget);
  });

  testWidgets('shows the server section first, and hides the proxy while connected', (tester) async {
    await pumpView(tester);
    expect(find.byType(ServerSection), findsOneWidget);
    expect(find.text('Web CORS proxy'), findsOneWidget);

    server = FakeServerRepository(const ServerSession(url: 'https://srv.test', token: 't', phone: '+919876543210'));
    await pumpView(tester);
    expect(find.text('Signed in as +91 98765 43210'), findsOneWidget);
    expect(find.text('Web CORS proxy'), findsNothing);
  });
}
