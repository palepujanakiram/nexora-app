import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/usecase/connect_server_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/disconnect_server_usecase.dart';
import 'package:nexora_app/screens/settings/usecase/get_server_ip_usecase.dart';
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

  Future<void> pump(WidgetTester tester, [ServerSession? session]) async {
    server = FakeServerRepository(session);
    Future<void> switchTo(ServerSession? s) async => switches.add(s?.email);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => ServerViewModel(
            WatchServerUseCase(server),
            ConnectServerUseCase(server, switchTo),
            DisconnectServerUseCase(server, switchTo),
            GetServerIpUseCase(server),
          ),
          child: const ServerSection(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('signs in through the dialog', (tester) async {
    await pump(tester);
    expect(find.textContaining('Connect to your nexora-backend server'), findsOneWidget);
    await tester.tap(find.text('Connect to a server'));
    await tester.pumpAndSettle();
    expect(find.text('Connect to a server'), findsWidgets);

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(3));

    await tester.enterText(field('Server address'), 'https://srv.test');
    await tester.enterText(field('Email'), 'me@x.com');
    await tester.enterText(field('Password'), 'long enough pw');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(server.calls, ['signIn https://srv.test me@x.com']);
    expect(switches, ['me@x.com']);
    expect(find.text('Signed in as me@x.com'), findsOneWidget);
    expect(find.text('https://srv.test'), findsOneWidget);
  });

  testWidgets('creates a login with an invite code, and shows errors in the dialog', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Connect to a server'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Create a server login'), findsOneWidget);
    expect(find.text('At least 10 characters.'), findsOneWidget);

    await tester.enterText(field('Server address'), 'https://srv.test');
    await tester.enterText(field('Email'), 'new@x.com');
    await tester.enterText(field('Password'), 'long enough pw');
    await tester.enterText(field('Invite code'), 'family');
    server.failWith = 'Wrong invite code.';
    await tester.tap(find.text('Create login'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Wrong invite code.'), findsWidgets);

    server.failWith = null;
    await tester.tap(find.text('Create login'));
    await tester.pumpAndSettle();
    expect(server.calls.last, 'register https://srv.test new@x.com family');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('cancel closes the dialog without connecting', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Connect to a server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(server.calls, isEmpty);
  });

  testWidgets('shows and copies the server IP, then disconnects after confirming', (tester) async {
    await pump(tester, const ServerSession(url: 'https://srv.test', token: 't', email: 'me@x.com'));
    await tester.tap(find.text('Show server IP'));
    await tester.pumpAndSettle();
    expect(find.text('Server IP: 203.0.113.7'), findsOneWidget);
    expect(find.text('Show server IP'), findsNothing);
    await tester.tap(find.byTooltip('Copy IP'));
    expect(clipboard, ['203.0.113.7']);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect from the server?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.calls, isEmpty);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();
    expect(server.calls, ['signOut']);
    expect(switches, [null]);
    expect(find.text('Connect to a server'), findsOneWidget);
  });

  testWidgets('shows why the IP lookup failed', (tester) async {
    await pump(tester, const ServerSession(url: 'https://srv.test', token: 't', email: 'me@x.com'));
    server.failWith = 'Couldn\'t reach the server.';
    await tester.tap(find.text('Show server IP'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t reach the server.'), findsOneWidget);
  });
}
