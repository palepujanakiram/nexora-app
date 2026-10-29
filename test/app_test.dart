import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/app.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/app_settings.dart';
import 'package:nexora_app/common/domain/repositories/settings_repository.dart';
import 'package:nexora_app/common/presentation/theme/app_theme.dart';
import 'package:nexora_app/screens/home/view/home_view.dart';
import 'package:nexora_app/screens/login/view/login_view.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await sl.reset();
    SharedPreferences.setMockInitialValues({'app_settings_v1': '{"themeColor":"purple"}'});
    FlutterSecureStorage.setMockInitialValues({});
    await configureDependencies();
  });

  tearDown(() => sl.reset());

  MaterialApp app(WidgetTester tester) => tester.widget<MaterialApp>(find.byType(MaterialApp));

  testWidgets('starts with the saved theme colour and, signed out, the login screen', (tester) async {
    await tester.pumpWidget(const NexoraApp());
    await tester.pump();

    final a = app(tester);
    expect(a.title, 'NexoraApp');
    expect(a.debugShowCheckedModeBanner, isFalse);
    expect(a.theme!.colorScheme, AppTheme.light(ThemeColor.purple).colorScheme);
    expect(a.darkTheme!.colorScheme, AppTheme.dark(ThemeColor.purple).colorScheme);
    expect(a.darkTheme!.brightness, Brightness.dark);
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.byType(HomeView), findsNothing);
  });

  testWidgets('a saved session opens home; a session the server rejects goes back to login', (tester) async {
    await sl.reset();
    FlutterSecureStorage.setMockInitialValues({
      'server_session_v1': '{"url":"https://srv.test","token":"old","email":"me@x.com"}',
    });
    var accepted = true;
    final client = MockClient((_) async => accepted
        ? http.Response('{"accounts":[],"executions":[]}', 200)
        : http.Response('{"error":{"code":"unauthorized","message":"Sign in again."}}', 401));
    await tester.runAsync(() => configureDependencies(httpClient: client));

    await tester.pumpWidget(const NexoraApp());
    await tester.runAsync(pumpEventQueue);
    await tester.pump();
    expect(find.byType(HomeView), findsOneWidget);

    accepted = false;
    await tester.tap(find.text('Accounts'));
    await tester.runAsync(pumpEventQueue);
    await tester.pumpAndSettle();
    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
  });

  testWidgets('rebuilds the theme when the colour is changed in settings', (tester) async {
    await tester.pumpWidget(const NexoraApp());
    await tester.pump();

    final repo = sl<SettingsRepository>();
    await tester.runAsync(() => repo.save(repo.current.copyWith(themeColor: ThemeColor.orange)));
    await tester.pump();

    expect(app(tester).theme!.colorScheme, AppTheme.light(ThemeColor.orange).colorScheme);
    expect(app(tester).darkTheme!.colorScheme, AppTheme.dark(ThemeColor.orange).colorScheme);
  });
}
