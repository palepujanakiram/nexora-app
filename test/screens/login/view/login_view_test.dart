import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';
import 'package:nexora_app/screens/login/view/login_view.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  setUp(() async {
    await sl.reset();
    server = FakeServerRepository();
    switches = [];
    sl
      ..registerFactory(() => SignInUseCase(server, (s) async => switches.add(s?.email)))
      ..registerFactory(() => GetSignInNoticeUseCase(server));
  });

  tearDown(() => sl.reset());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LoginView()));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('signs in to the default server', (tester) async {
    await pump(tester);
    expect(find.text('Sign in to your server'), findsOneWidget);
    expect(find.text(ServerSession.defaultUrl), findsOneWidget, reason: 'shown under Server');
    expect(ServerSession.defaultUrl, 'https://nexora-backend-jp.fly.dev');

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));
    expect(server.calls, isEmpty);

    await tester.enterText(field('Email'), 'me@x.com');
    await tester.enterText(field('Password'), 'pw');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(server.calls, ['signIn ${ServerSession.defaultUrl} me@x.com']);
    expect(switches, ['me@x.com']);
  });

  testWidgets('shows and hides the password', (tester) async {
    await pump(tester);
    bool obscured() => tester.widget<EditableText>(find.descendant(of: field('Password'), matching: find.byType(EditableText))).obscureText;
    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  testWidgets('creates a login with an invite code, showing errors', (tester) async {
    await pump(tester);
    await tester.tap(find.text('New here? Create a login'));
    await tester.pumpAndSettle();
    expect(find.text('Create your login'), findsOneWidget);
    expect(find.text('At least 10 characters.'), findsOneWidget);

    await tester.enterText(field('Email'), 'new@x.com');
    await tester.enterText(field('Password'), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create login'));
    await tester.pump();
    expect(find.text('Use at least 10 characters.'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget, reason: 'invite code');

    await tester.enterText(field('Password'), 'long enough pw');
    await tester.enterText(field('Invite code'), 'family');
    server.failWith = 'Wrong invite code.';
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Wrong invite code.'), findsOneWidget);
    expect(switches, isEmpty);

    server.failWith = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Create login'));
    await tester.pumpAndSettle();
    expect(server.calls.last, 'register ${ServerSession.defaultUrl} new@x.com family');
    expect(switches, ['new@x.com']);

    await tester.tap(find.text('Have a login? Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your server'), findsOneWidget);
    expect(field('Invite code'), findsNothing);
  });

  testWidgets('signs in to another server, and can go back to the default', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Server'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Server address'), 'http://localhost:8080');
    await tester.pump();
    expect(find.text('http://localhost:8080'), findsWidgets);

    await tester.tap(find.byTooltip('Use the default server'));
    await tester.pump();
    expect(find.text(ServerSession.defaultUrl), findsWidgets);

    await tester.enterText(field('Server address'), '');
    await tester.enterText(field('Email'), 'me@x.com');
    await tester.enterText(field('Password'), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);

    await tester.enterText(field('Server address'), 'http://localhost:8080');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(server.calls, ['signIn http://localhost:8080 me@x.com']);
  });

  testWidgets('explains why the session ended', (tester) async {
    server.expire('Your session ended. Sign in again.');
    await pump(tester);
    expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
  });
}
