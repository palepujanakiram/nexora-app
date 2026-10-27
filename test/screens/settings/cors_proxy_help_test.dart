import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
