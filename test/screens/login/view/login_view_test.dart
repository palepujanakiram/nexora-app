import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/server_session.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/send_code_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';
import 'package:nexora_app/screens/login/view/login_view.dart';
import 'package:nexora_app/screens/login/viewmodel/login_viewmodel.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  setUp(() async {
    await sl.reset();
    server = FakeServerRepository();
    switches = [];
    sl
      ..registerFactory(() => SendCodeUseCase(server))
      ..registerFactory(() => SignInUseCase(server, (s) async => switches.add(s?.phone)))
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

  final mobile = find.byKey(const Key('mobile'));
  final code = find.byKey(const Key('code'));
  Finder button(String label) => find.widgetWithText(FilledButton, label);

  Future<void> sendCode(WidgetTester tester, [String number = '9876543210']) async {
    await tester.enterText(mobile, number);
    await tester.tap(button('Send code'));
    await tester.pump();
  }

  testWidgets('asks for the mobile number, then signs in with the texted code', (tester) async {
    await pump(tester);
    expect(find.text('SRISARANI\nSTOCKS'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in with your mobile number. We will send you a one-time code.'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('10-digit number'), findsOneWidget);
    expect(find.text(ServerSession.defaultUrl), findsOneWidget, reason: 'shown under Server');
    expect(ServerSession.defaultUrl, 'https://nexora-backend-jp.fly.dev');

    await tester.tap(button('Send code'));
    await tester.pump();
    expect(find.text('Enter your 10-digit mobile number.'), findsOneWidget);
    await tester.enterText(mobile, '98765abc43210');
    expect(tester.widget<TextFormField>(mobile).controller!.text, '9876543210', reason: 'digits only, at most 10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(server.calls, ['requestCode ${ServerSession.defaultUrl} +919876543210']);

    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.textContaining('We sent a 6-digit code to +91 98765 43210.', findRichText: true), findsOneWidget);
    expect(find.text('Resend code in 0:30'), findsOneWidget);
    expect(find.text('Server'), findsNothing);

    // A full code is checked as soon as it's in, e.g. when iOS fills it from the SMS.
    await tester.enterText(code, '123456');
    await tester.pump();
    expect(server.calls.last, 'verifyCode ${ServerSession.defaultUrl} +919876543210 123456');
    expect(switches, ['+919876543210']);
  });

  testWidgets('explains a bad number and clears the error once it is fixed', (tester) async {
    await pump(tester);
    await sendCode(tester, '1234567890');
    expect(find.text('Indian mobile numbers start with 6, 7, 8 or 9.'), findsOneWidget);

    await tester.enterText(mobile, '98765');
    await tester.pump();
    expect(find.text('Enter your 10-digit mobile number.'), findsOneWidget, reason: 're-checked while typing');
    await tester.enterText(mobile, '9876543210');
    await tester.pump();
    expect(find.text('Enter your 10-digit mobile number.'), findsNothing);
    expect(server.calls, isEmpty);
  });

  testWidgets('shows a wrong code, then verifies with the button', (tester) async {
    await pump(tester);
    await sendCode(tester);
    await tester.enterText(code, '000000');
    await tester.pump();
    expect(find.text('Wrong code. 4 tries left.'), findsOneWidget);
    expect(switches, isEmpty);

    await tester.enterText(code, '12345');
    await tester.tap(button('Verify and continue'));
    await tester.pump();
    expect(find.text('Enter the 6-digit code from the SMS.'), findsOneWidget);

    server.code = '12345';
    await tester.enterText(code, '12345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Enter the 6-digit code from the SMS.'), findsOneWidget, reason: 'still five digits');

    server.code = '123456';
    await tester.enterText(code, '123456');
    await tester.pump();
    expect(switches, ['+919876543210']);
  });

  testWidgets('resends after the countdown, and can change the number', (tester) async {
    await pump(tester);
    await sendCode(tester);
    await tester.enterText(code, '11');
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Didn\'t get it?'), findsOneWidget);
    await tester.tap(find.text('Resend'));
    await tester.pump();
    expect(server.calls.where((c) => c.startsWith('requestCode')), hasLength(2));
    expect(tester.widget<TextField>(code).controller!.text, isEmpty, reason: 'a new code clears the old one');
    expect(find.text('Resend code in 0:30'), findsOneWidget);
    await tester.tap(find.text('Resend'));
    await tester.pump();
    expect(server.calls.where((c) => c.startsWith('requestCode')), hasLength(2), reason: 'Resend waits for the countdown');

    await tester.tap(find.text('Change number'));
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.widget<TextFormField>(mobile).controller!.text, '9876543210', reason: 'kept to fix a typo');

    await sendCode(tester);
    await tester.tap(find.text('← Back'));
    await tester.pump();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('shows a spinner and blocks a second tap while the code is on its way', (tester) async {
    await pump(tester);
    server.hold = Completer<void>();
    await sendCode(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    server.hold!.complete();
    await tester.pump();
    expect(find.text('Enter the code'), findsOneWidget);
  });

  testWidgets('closes the keyboard when tapping outside the field', (tester) async {
    await pump(tester);
    await tester.tap(mobile);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextFormField>(), isNotNull);

    await tester.tapAt(const Offset(400, 40));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<TextFormField>(), isNull);
  });

  testWidgets('shows each typed digit in its own box', (tester) async {
    await pump(tester);
    await sendCode(tester);
    await tester.enterText(code, '42');
    await tester.pump();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(server.calls.where((c) => c.startsWith('verifyCode')), isEmpty, reason: 'waits for all six digits');
  });

  testWidgets('uses darker colours in dark mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: Brightness.dark), home: const LoginView()));
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, const Color(0xFF0E1A18));
  });

  testWidgets('shows why a code could not be sent', (tester) async {
    await pump(tester);
    server.failWith = "This number isn't allowed to sign in. Ask the server owner to add it.";
    await sendCode(tester);
    expect(find.text("This number isn't allowed to sign in. Ask the server owner to add it."), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('explains that a number with no account cannot sign in, without asking for anything else', (tester) async {
    await pump(tester);
    server.unknownPhones.add('+919030863940');
    await sendCode(tester, '9030863940');
    expect(find.text(LoginViewModel.userNotFound), findsOneWidget);
    expect(LoginViewModel.userNotFound, startsWith('We couldn\'t find an account for this number.'));
    expect(find.textContaining('Invite'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('sends the code through another server, and can go back to the default', (tester) async {
    await pump(tester);
    final address = find.widgetWithText(TextFormField, 'Server address');
    await tester.tap(find.text('Server'));
    await tester.pumpAndSettle();
    await tester.enterText(address, 'http://localhost:8080');
    await tester.pump();
    expect(find.text('http://localhost:8080'), findsWidgets);

    await tester.tap(find.byTooltip('Use the default server'));
    await tester.pump();
    expect(find.text(ServerSession.defaultUrl), findsWidgets);

    await tester.enterText(address, '');
    await sendCode(tester);
    expect(find.text('Required'), findsOneWidget);
    expect(server.calls, isEmpty);

    await tester.enterText(address, 'http://localhost:8080');
    await sendCode(tester);
    expect(server.calls, ['requestCode http://localhost:8080 +919876543210']);
  });

  testWidgets('explains why the session ended', (tester) async {
    server.expire('Your session ended. Sign in again.');
    await pump(tester);
    expect(find.text('Your session ended. Sign in again.'), findsOneWidget);
  });
}
