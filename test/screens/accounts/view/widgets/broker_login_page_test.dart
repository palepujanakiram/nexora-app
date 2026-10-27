import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/accounts/model/login_redirect.dart';
import 'package:nexora_app/screens/accounts/view/widgets/broker_login_page.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../../fake_webview_platform.dart';

void main() {
  const redirect = LoginRedirect(codeParam: 'code', redirectUri: 'https://127.0.0.1/');
  const loginUrl = 'https://api.upstox.com/v2/login/authorization/dialog?client_id=k';

  late FakeWebViewPlatform platform;

  setUp(() => WebViewPlatform.instance = platform = FakeWebViewPlatform());

  /// Opens the page from a button and records what it returns.
  Future<List<String?>> open(WidgetTester tester) async {
    final results = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              results.add(await BrokerLoginPage.open(context, title: 'Upstox login', loginUrl: loginUrl, redirect: redirect)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    // The loading bar animates until the page reports progress, so don't wait to settle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return results;
  }

  testWidgets('loads the login page with JavaScript, full screen, with a progress bar', (tester) async {
    await open(tester);
    expect(find.text('Upstox login'), findsOneWidget);
    expect(find.text('fake browser'), findsOneWidget);
    expect(platform.controller!.loaded, Uri.parse(loginUrl));
    expect(platform.controller!.javaScriptMode, JavaScriptMode.unrestricted);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    platform.delegate!.onProgress!(40);
    await tester.pump();
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.4);

    platform.delegate!.onProgress!(100);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('broker pages load; the redirect is blocked and returned', (tester) async {
    final results = await open(tester);

    expect(await platform.navigate('https://login.upstox.com/otp'), NavigationDecision.navigate);
    expect(results, isEmpty);

    expect(await platform.navigate('https://127.0.0.1/?code=AbC123'), NavigationDecision.prevent);
    await tester.pumpAndSettle();
    expect(results, ['https://127.0.0.1/?code=AbC123']);
    expect(find.text('fake browser'), findsNothing);
  });

  testWidgets('a redirect seen first by onPageStarted or onUrlChange also ends the login, once', (tester) async {
    final results = await open(tester);

    platform.delegate!.onUrlChange!(const UrlChange(url: null));
    platform.delegate!.onPageStarted!('https://login.upstox.com/');
    await tester.pump();
    expect(results, isEmpty);

    platform.delegate!.onPageStarted!('https://127.0.0.1/?code=X');
    platform.delegate!.onUrlChange!(const UrlChange(url: 'https://127.0.0.1/?code=X'));
    await tester.pumpAndSettle();
    expect(results, ['https://127.0.0.1/?code=X'], reason: 'popped only once');
  });

  testWidgets('closing the page returns nothing', (tester) async {
    final results = await open(tester);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(results, [null]);
  });
}
