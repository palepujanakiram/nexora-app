import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/accounts/usecase/check_broker_login_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/get_login_url_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/login_with_redirect_usecase.dart';
import 'package:nexora_app/screens/accounts/usecase/set_access_token_usecase.dart';
import 'package:nexora_app/screens/accounts/view/widgets/login_dialog.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../../../fakes.dart';
import '../../fake_webview_platform.dart';

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
        ..registerFactory(() => CheckBrokerLoginUseCase(broker))
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

  /// The paste flow by default (as on the web); [inAppBrowser] adds the in-app login.
  Future<void> openDialog(WidgetTester tester, [BrokerAccount? account, bool inAppBrowser = false]) async {
    final a = account ?? accounts.current.single;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => LoginDialog.show(context, a, inAppBrowser: inAppBrowser),
            child: const Text('open'),
          ),
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

  testWidgets('with a server holding the tokens, pasting one is not offered', (tester) async {
    broker.acceptsAccessTokens = false;
    await openDialog(tester);
    expect(find.text('Generate session'), findsOneWidget);
    expect(find.text('It is an access token'), findsNothing);
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

  testWidgets('Groww: approve on the API keys page, then generate without pasting', (tester) async {
    final groww = testAccount(loggedIn: false).copyWith(broker: BrokerType.groww);
    accounts = FakeAccountRepository([groww]);
    sl
      ..unregister<LoginWithRedirectUseCase>()
      ..registerFactory(() => LoginWithRedirectUseCase(broker, accounts));
    await openDialog(tester, groww);

    expect(find.textContaining('approve today\'s access'), findsOneWidget);
    expect(find.textContaining('Tap Generate session'), findsOneWidget);
    expect(find.text('TOTP code (optional)'), findsOneWidget);

    await tester.tap(find.text('Open API keys page'));
    await tester.pumpAndSettle();
    expect((launches.single.arguments as Map)['url'], 'https://login.example/a');

    await tester.tap(find.text('Generate session'));
    await tester.pumpAndSettle();
    expect(broker.inputs, ['']);
    expect(find.byType(AlertDialog), findsNothing);
    expect(accounts.current.single.hasValidToken, isTrue);
  });

  group('in-app login', () {
    late FakeWebViewPlatform browser;

    setUp(() => WebViewPlatform.instance = browser = FakeWebViewPlatform());

    Finder logInButton() => find.widgetWithText(FilledButton, 'Log in');

    Future<void> tapLogIn(WidgetTester tester) async {
      await tester.tap(logInButton());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('offers Log in first, with the browser and paste flow as a fallback', (tester) async {
      await openDialog(tester, null, true);
      expect(find.text('Sign in on the broker\'s page. Srisarani Stocks picks up the login by itself.'), findsOneWidget);
      expect(logInButton(), findsOneWidget);
      expect(find.text('Or log in in your browser:'), findsOneWidget);
      expect(find.text('Open in browser'), findsOneWidget);
      expect(find.text('Open login page'), findsNothing);
      expect(find.text('Generate session'), findsOneWidget);
    });

    testWidgets('Zerodha: the redirect is caught and the session created without pasting', (tester) async {
      await openDialog(tester, null, true);
      await tapLogIn(tester);
      expect(find.text('Zerodha login'), findsOneWidget);
      expect(browser.controller!.loaded.toString(), 'https://login.example/a');

      final url = 'https://127.0.0.1/?action=login&status=success&request_token=rt42';
      expect(await browser.navigate(url), NavigationDecision.prevent);
      await settle(tester);

      expect(broker.inputs, [url]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(accounts.current.single.accessToken, 'token-$url');
    });

    testWidgets('Upstox: waits for its redirect URI and calls the page "Upstox login"', (tester) async {
      final upstox = testAccount(loggedIn: false).copyWith(broker: BrokerType.upstox, redirectUri: 'https://127.0.0.1/');
      accounts = FakeAccountRepository([upstox]);
      await sl.reset();
      sl
        ..registerFactory(() => GetLoginUrlUseCase(broker))
        ..registerFactory(() => CheckBrokerLoginUseCase(broker))
        ..registerFactory(() => LoginWithRedirectUseCase(broker, accounts))
        ..registerFactory(() => SetAccessTokenUseCase(accounts));
      await openDialog(tester, upstox, true);
      await tapLogIn(tester);
      expect(find.text('Upstox login'), findsOneWidget);

      expect(await browser.navigate('https://login.upstox.com/?code=not-the-redirect'), NavigationDecision.navigate);
      expect(await browser.navigate('https://127.0.0.1/?code=up1'), NavigationDecision.prevent);
      await settle(tester);
      expect(broker.inputs, ['https://127.0.0.1/?code=up1']);
      expect(accounts.current.single.hasValidToken, isTrue);
    });

    testWidgets('closing the login page keeps the dialog open without logging in', (tester) async {
      await openDialog(tester, null, true);
      await tapLogIn(tester);
      await tester.tap(find.byTooltip('Cancel'));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(broker.inputs, isEmpty);
    });

    testWidgets('a failed exchange after the redirect shows the error and keeps the dialog', (tester) async {
      broker.error = Exception('Kite: Token is invalid or has expired.');
      await openDialog(tester, null, true);
      await tapLogIn(tester);
      await browser.navigate('https://127.0.0.1/?request_token=old');
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('Token is invalid'), findsOneWidget);
    });

    testWidgets('Groww keeps its approval flow (no in-app login)', (tester) async {
      final groww = testAccount(loggedIn: false).copyWith(broker: BrokerType.groww);
      await openDialog(tester, groww, true);
      expect(logInButton(), findsNothing);
      expect(find.text('Open API keys page'), findsOneWidget);
    });
  });

  group('with a server finishing the login', () {
    late FakeWebViewPlatform platform;

    setUp(() {
      WebViewPlatform.instance = platform = FakeWebViewPlatform();
      broker
        ..loginFinishesOnServer = true
        ..acceptsAccessTokens = false;
    });

    testWidgets('Log in opens Safari\'s in-app view, waits, and closes once the server has the login', (tester) async {
      broker.loginChecks = [false, true];
      await openDialog(tester, null, true);
      expect(find.textContaining('When it says "Account linked", close it'), findsOneWidget);
      expect(find.text('Open login page'), findsOneWidget, reason: 'the browser fallback stays');

      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pump();
      final args = launches.single.arguments as Map;
      expect(args['url'], 'https://login.example/a');
      expect(args['useSafariVC'], isTrue);
      expect(find.text('Waiting for the broker login to finish…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Log in')).onPressed, isNull);
      expect(platform.controller, isNull, reason: 'the app\'s own web view isn\'t used');

      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(broker.checked, ['a', 'a']);
    });

    testWidgets('closing the dialog while waiting stops asking', (tester) async {
      await openDialog(tester, null, true);
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pump();
      await tester.tapAt(const Offset(5, 5)); // outside the dialog
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(broker.checked, isEmpty);
    });
  });
}
