import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/settings/usecase/change_password_usecase.dart';
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
    server = FakeServerRepository(const ServerSession(url: 'https://srv.test', token: 't', email: 'me@x.com'));
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
            ChangePasswordUseCase(server, switchTo),
            GetServerIpUseCase(server),
          ),
          child: const ServerSection(),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('shows who is signed in, and shows and copies the server IP', (tester) async {
    await pump(tester);
    expect(find.text('Signed in as me@x.com'), findsOneWidget);
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
    expect(find.text('Signed in as me@x.com'), findsNothing);
  });

  testWidgets('changes the password, checking the fields and showing server errors', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Your other devices will be signed out.'), findsOneWidget);

    final submit = find.widgetWithText(FilledButton, 'Change password');
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Use at least 10 characters.'), findsOneWidget);

    await tester.enterText(field('Current password'), 'old password');
    await tester.enterText(field('New password'), 'new password');
    await tester.enterText(field('Repeat new password'), 'typo password');
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('The passwords don\'t match.'), findsOneWidget);

    await tester.enterText(field('Repeat new password'), 'new password');
    server.failWith = 'Current password is wrong.';
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Current password is wrong.'), findsWidgets);

    server.failWith = null;
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(server.calls.last, 'changePassword old password new password');
    expect(switches, ['tok2']);
    expect(find.text('Password changed. Other devices were signed out.'), findsOneWidget);
  });

  testWidgets('cancel closes the password dialog without changing anything', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('Password changed'), findsNothing);
    expect(server.calls, isEmpty);
  });

  testWidgets('shows why the IP lookup failed', (tester) async {
    await pump(tester);
    server.failWith = 'Couldn\'t reach the server.';
    await tester.tap(find.text('Show server IP'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t reach the server.'), findsOneWidget);
  });
}
