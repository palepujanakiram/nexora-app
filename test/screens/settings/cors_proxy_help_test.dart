import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/settings/model/cors_proxy_guide.dart';
import 'package:nexora_app/screens/settings/view/widgets/cors_proxy_help.dart';

void main() {
  const code = "export default { fetch() {} } // nexora";

  Future<List<String>> pump(WidgetTester tester, {required bool clipboardWorks}) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (!clipboardWorks) throw PlatformException(code: 'copy_fail', message: 'Clipboard.setData failed');
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CorsProxyHelp(loadWorkerScript: () async => code, initiallyExpanded: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return copied;
  }

  testWidgets('copies the worker code', (tester) async {
    final copied = await pump(tester, clipboardWorks: true);
    await tester.tap(find.text('Copy proxy code'));
    await tester.pumpAndSettle();
    expect(copied, [code]);
    expect(find.textContaining('Proxy code copied'), findsOneWidget);
  });

  testWidgets('shows the code to select when the clipboard is blocked', (tester) async {
    await pump(tester, clipboardWorks: false);
    await tester.tap(find.text('Copy proxy code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your browser blocked copying'), findsOneWidget);
    expect(find.text(code), findsOneWidget);
  });

  testWidgets('View code opens a selectable copy that can be closed', (tester) async {
    await pump(tester, clipboardWorks: true);
    await tester.tap(find.text('View code'));
    await tester.pumpAndSettle();
    expect(find.text('Proxy code'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, code), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Proxy code'), findsNothing);
  });

  testWidgets('shows every step and note, and links open externally', (tester) async {
    final launched = <Map<Object?, Object?>>[];
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') launched.add(call.arguments as Map<Object?, Object?>);
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await pump(tester, clipboardWorks: true);

    for (final (i, step) in CorsProxyGuide.steps.indexed) {
      expect(find.text('${i + 1}.'), findsOneWidget);
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text(CorsProxyGuide.defaultsNote), findsOneWidget);
    expect(find.text(CorsProxyGuide.cliNote), findsOneWidget);

    for (final link in CorsProxyGuide.links) {
      await tester.ensureVisible(find.text(link.label));
      await tester.tap(find.text(link.label));
      await tester.pumpAndSettle();
    }
    expect(launched.map((a) => a['url']), CorsProxyGuide.links.map((l) => l.url));
  });

  testWidgets('starts collapsed and disables the code buttons until the code loads', (tester) async {
    final pending = Completer<String>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: CorsProxyHelp(loadWorkerScript: () => pending.future))),
    ));
    expect(find.text('How to create the proxy (free Cloudflare Worker)'), findsOneWidget);
    expect(find.text('Copy proxy code'), findsNothing);

    await tester.tap(find.text('How to create the proxy (free Cloudflare Worker)'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'View code')).onPressed, isNull);
    expect(tester.widget<ButtonStyleButton>(
            find.ancestor(of: find.text('Copy proxy code'), matching: find.bySubtype<ButtonStyleButton>()))
        .onPressed, isNull);

    pending.complete(code);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'View code')).onPressed, isNotNull);
  });

  testWidgets('a script that loads after the widget is gone is ignored', (tester) async {
    final pending = Completer<String>();
    await tester.pumpWidget(MaterialApp(home: CorsProxyHelp(loadWorkerScript: () => pending.future)));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(code);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
