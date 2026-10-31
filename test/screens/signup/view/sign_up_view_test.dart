import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/screens/login/usecase/get_sign_in_notice_usecase.dart';
import 'package:nexora_app/screens/login/usecase/send_code_usecase.dart';
import 'package:nexora_app/screens/login/usecase/sign_in_usecase.dart';
import 'package:nexora_app/screens/login/view/login_view.dart';
import 'package:nexora_app/screens/signup/model/sign_up_consent.dart';
import 'package:nexora_app/screens/signup/usecase/send_sign_up_code_usecase.dart';
import 'package:nexora_app/screens/signup/usecase/sign_up_usecase.dart';
import 'package:nexora_app/screens/signup/view/sign_up_view.dart';

import '../../../fakes.dart';

void main() {
  late FakeServerRepository server;
  late List<String?> switches;

  setUp(() async {
    await sl.reset();
    server = FakeServerRepository();
    switches = [];
    Future<void> switchTo(s) async => switches.add(s?.phone);
    sl
      ..registerFactory(() => SendCodeUseCase(server))
      ..registerFactory(() => SignInUseCase(server, switchTo))
      ..registerFactory(() => GetSignInNoticeUseCase(server))
      ..registerFactory(() => SendSignUpCodeUseCase(server))
      ..registerFactory(() => SignUpUseCase(server, switchTo));
  });

  tearDown(() => sl.reset());

  /// Sign-up opened from the sign-in screen, as in the app.
  Future<void> open(WidgetTester tester, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: theme, home: const LoginView()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
  }

  final name = find.byKey(const Key('fullName'));
  final mobile = find.byKey(const Key('mobile'));
  final email = find.byKey(const Key('email'));
  final code = find.byKey(const Key('code'));
  Finder button(String label) => find.widgetWithText(FilledButton, label);
  Finder consent(SignUpConsent c) => find.byKey(Key('consent-${c.name}'));

  Future<void> fillForm(WidgetTester tester, {String emailText = 'ravi@example.com', bool tick = true}) async {
    await tester.enterText(name, 'Ravi Kumar');
    await tester.enterText(mobile, '9876543210');
    await tester.enterText(email, emailText);
    if (tick) {
      for (final c in SignUpConsent.values) {
        await tester.tap(consent(c));
      }
    }
    await tester.pump();
  }

  Future<void> create(WidgetTester tester) async {
    await tester.ensureVisible(button('Create account and send code'));
    await tester.tap(button('Create account and send code'));
    await tester.pump();
  }

  testWidgets('fills in the form, then creates the account with the texted code', (tester) async {
    await open(tester);
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('It takes about a minute.'), findsOneWidget);
    for (final text in ['Full name', 'As on your PAN', 'Mobile number', '+91', '10-digit number', 'Email', 'you@example.com']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text('PLEASE CONFIRM EACH OF THESE'), findsOneWidget);
    for (final c in SignUpConsent.values) {
      expect(find.text(c.statement), findsOneWidget);
    }
    expect(find.text('Already have an account? '), findsOneWidget);

    await fillForm(tester);
    expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).every((c) => c.value!), isTrue);
    await create(tester);
    expect(server.calls, ['requestSignUpCode https://nexora-backend-jp.fly.dev +919876543210 Ravi Kumar ravi@example.com']);

    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.textContaining('We sent a 6-digit code to +91 98765 43210.', findRichText: true), findsOneWidget);
    expect(find.text('Resend code in 0:30'), findsOneWidget);

    await tester.enterText(code, '123456');
    await tester.pumpAndSettle();
    expect(server.calls.last, 'verifySignUp https://nexora-backend-jp.fly.dev +919876543210 Ravi Kumar ravi@example.com 123456');
    expect(switches, ['+919876543210']);
    expect(find.byType(SignUpView), findsNothing, reason: 'closed so the app\'s home shows');
  });

  testWidgets('explains each problem with the form before sending anything', (tester) async {
    await open(tester);
    await create(tester);
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter your 10-digit mobile number.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    await fillForm(tester, tick: false);
    expect(find.text('Enter your full name.'), findsNothing, reason: 're-checked while typing');
    await tester.tap(consent(SignUpConsent.terms));
    // The checkbox itself ticks too, and ticking twice unticks.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.tap(find.byType(Checkbox).at(1));
    await create(tester);
    expect(find.text('Please confirm each of the statements to create your account.'), findsOneWidget);
    expect(server.calls, isEmpty);
  });

  testWidgets('a number with an account goes back to sign in, with the number filled in', (tester) async {
    await open(tester);
    server.registeredPhones.add('+919876543210');
    await fillForm(tester);
    await create(tester);
    await tester.enterText(code, '123456');
    await tester.pump();
    expect(find.text('This mobile number already has an account. Sign in instead.'), findsOneWidget);
    expect(switches, isEmpty);

    await tester.tap(find.text('Sign in instead'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.widget<TextFormField>(mobile).controller!.text, '9876543210');
  });

  testWidgets('an email that is taken goes back to the form to fix it', (tester) async {
    await open(tester);
    server.registeredEmails.add('taken@example.com');
    await fillForm(tester, emailText: 'taken@example.com');
    await create(tester);
    await tester.enterText(code, '123456');
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('An account with this email already exists.'), findsOneWidget);
    expect(find.text('Sign in instead'), findsNothing);
    expect(tester.widget<TextFormField>(name).controller!.text, 'Ravi Kumar', reason: 'the form is kept');
  });

  testWidgets('resends, goes back to edit the form, and back to sign in', (tester) async {
    await open(tester);
    await fillForm(tester);
    await create(tester);
    await tester.enterText(code, '11');
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.text('Resend'));
    await tester.pump();
    expect(server.calls.where((c) => c.startsWith('requestSignUpCode')), hasLength(2));
    expect(tester.widget<TextField>(code).controller!.text, isEmpty, reason: 'a new code clears the old one');

    await tester.tap(find.text('Change number'));
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);
    expect(tester.widget<TextFormField>(mobile).controller!.text, '9876543210');

    await tester.tap(find.text('← Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.widget<TextFormField>(mobile).controller!.text, isEmpty, reason: 'nothing to fill in');

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('shows a spinner and locks the form while the code is on its way', (tester) async {
    await open(tester);
    server.hold = Completer<void>();
    await fillForm(tester);
    await create(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).every((c) => c.onChanged == null), isTrue);

    server.hold!.complete();
    await tester.pump();
    expect(find.text('Enter the code'), findsOneWidget);
  });

  testWidgets('shows why the code could not be sent', (tester) async {
    await open(tester);
    server.failWith = 'Too many codes. Try again in 40 minutes.';
    await fillForm(tester);
    await create(tester);
    expect(find.text('Too many codes. Try again in 40 minutes.'), findsOneWidget);
    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('uses darker colours in dark mode', (tester) async {
    await open(tester, theme: ThemeData(brightness: Brightness.dark));
    expect(tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor, const Color(0xFF0E1A18));
  });
}
