import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/accounts/usecase/get_login_url_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/login_with_redirect_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/set_access_token_usecase.dart';
import 'package:nexora_app/screens/accounts/view/widgets/login_dialog.dart';

import '../../../../fakes.dart';

class _ControlledBroker extends FakeBrokerRepository {
  Completer<String>? pending;
  Object? error;
  final inputs = <String>[];

  @override
  Future<String> exchangeToken(BrokerAccount account, String input) {
    inputs.add(input);
    if (error != null) return Future.error(error!);
    if (pending != null) return pending!.future;
    return super.exchangeToken(account, input);
  }
}

const _urlChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  late _ControlledBroker broker;
  late FakeAccountRepository accounts;
  late List<MethodCall> launches;
  late List<String> clipboard;

  setUp(() {
    broker = _ControlledBroker();
    accounts = FakeAccountRepository([testAccount(loggedIn: false)]);
    sl
      ..reset()
      ..registerFactory(() => GetLoginUrlUseCase(broker))
      ..registerFactory(() => LoginWithRedirectUseCase(broker, accounts))
      ..registerFactory(() => SetAccessTokenUseCase(accounts));

    launches = [];
    clipboard = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_urlChannel, (call) async {
      launches.add(call);
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard.add((call.arguments as Map)['text'] as String);
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_urlChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> openDialog(WidgetTester tester, [BrokerAccount? account]) async {
    final a = account ?? accounts.current.single;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => LoginDialog.show(context, a), child: const Text('open')),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the steps with the zerodha code name', (tester) async {
    await openDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Log in — Test a'), findsOneWidget);
    expect(find.text('1. Open the broker login page and sign in.'), findsOneWidget);
    expect(find.text('2. Paste the URL you were redirected to (or just the request_token).'), findsOneWidget);
    expect(find.text('Generate session'), findsOneWidget);
    expect(find.text('It is an access token'), findsOneWidget);
  });

  testWidgets('upstox asks for the code', (tester) async {
    await openDialog(tester, testAccount(id: 'u').copyWith(broker: BrokerType.upstox));
    expect(find.text('2. Paste the URL you were redirected to (or just the code).'), findsOneWidget);
  });

  testWidgets('Open login page launches the broker URL externally', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Open login page'));
    await tester.pumpAndSettle();

    expect(launches, hasLength(1));
    final args = launches.single.arguments as Map;
    expect(args['url'], 'https://login.example/a');
    expect(args['useSafariVC'], isFalse);
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'dialog stays open');
  });

  testWidgets('Copy link copies the login URL', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(clipboard, ['https://login.example/a']);
  });

  testWidgets('pasting the redirect URL exchanges the token and closes', (tester) async {
    await openDialog(tester);
    const redirect = 'https://127.0.0.1/?request_token=abc&status=success';
    await tester.enterText(find.byType(TextField), redirect);
    await tester.tap(find.text('Generate session'));
    await tester.pumpAndSettle();

    expect(broker.inputs, [redirect]);
    expect(accounts.current.single.accessToken, 'token-$redirect');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('pasting an access token stores it directly and closes', (tester) async {
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), '  direct-token ');
    await tester.tap(find.text('It is an access token'));
    await tester.pumpAndSettle();

    expect(broker.inputs, isEmpty);
    expect(accounts.current.single.accessToken, 'direct-token');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('empty input does nothing and keeps the dialog open', (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Generate session'));
    await tester.pumpAndSettle();

    expect(broker.inputs, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a failed exchange shows the error in the dialog', (tester) async {
    broker.error = Exception('Token is invalid or has expired');
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.tap(find.text('Generate session'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    final error = find.text('Exception: Token is invalid or has expired');
    expect(error, findsOneWidget);
    final context = tester.element(error);
    expect(tester.widget<Text>(error).style!.color, Theme.of(context).colorScheme.error);
    expect(accounts.current.single.accessToken, isNull);
  });

  testWidgets('shows a spinner and disables actions while busy', (tester) async {
    broker.pending = Completer<String>();
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'req');
    await tester.tap(find.text('Generate session'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Generate session'), findsNothing);
    expect(tester.widget<FilledButton>(find.ancestor(of: find.byType(CircularProgressIndicator), matching: find.byType(FilledButton))).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'It is an access token')).onPressed, isNull);

    broker.pending!.complete('tok');
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(accounts.current.single.accessToken, 'tok');
  });
}
