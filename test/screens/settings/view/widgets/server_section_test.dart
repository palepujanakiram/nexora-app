import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/sign_out_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/watch_server_usecase.dart';
import 'package:nexora_app/screens/settings/view/widgets/server_section.dart';
import 'package:nexora_app/screens/settings/viewmodel/server_viewmodel.dart';
import 'package:provider/provider.dart';

import '../../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;
  late List<String> clipboard;

  setUp(() {
    switches = [];
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
      return null;
    });
  });

  tearDown(() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  Future<void> pump(WidgetTester tester) async {
    server = FakeServerRepository(const ServerSession(url: 'https://srv.test', token: 't', phone: '+919876543210'));
    Future<void> switchTo(ServerSession? s) async => switches.add(s?.token);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => ServerViewModel(
            WatchServerUseCase(server),
            SignOutUseCase(server, switchTo),
            GetServerIpUseCase(server),
          ),
          child: const ServerSection(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows who is signed in, and shows and copies the server IP', (tester) async {
    await pump(tester);
    expect(find.text('Signed in as +91 98765 43210'), findsOneWidget);
    expect(find.text('https://srv.test'), findsOneWidget);

    await tester.tap(find.text('Show server IP'));
    await tester.pumpAndSettle();
    expect(find.text('Server IP: 203.0.113.7'), findsOneWidget);
    expect(find.text('Show server IP'), findsNothing);
    await tester.tap(find.byTooltip('Copy IP'));
    expect(clipboard, ['203.0.113.7']);
  });

  testWidgets('signs out after confirming', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.calls, isEmpty);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(server.calls, ['signOut']);
    expect(switches, [null]);
    expect(find.text('Signed in as +91 98765 43210'), findsNothing);
  });

  testWidgets('no longer offers a password change', (tester) async {
    await pump(tester);
    expect(find.text('Change password'), findsNothing);
  });

  testWidgets('shows why the IP lookup failed', (tester) async {
    await pump(tester);
    server.failWith = 'Couldn\'t reach the server.';
    await tester.tap(find.text('Show server IP'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t reach the server.'), findsOneWidget);
  });
}
