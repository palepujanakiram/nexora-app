import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/screens/account_edit/model/broker_setup_guide.dart';
import 'package:nexora_app/screens/account_edit/view/widgets/broker_setup_help.dart';

void main() {
  late List<String> launched;
  late List<String> copied;

  Future<void> pump(WidgetTester tester, BrokerSetupGuide guide) async {
    launched = [];
    copied = [];
    final messenger = tester.binding.defaultBinaryMessenger;
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    messenger.setMockMethodCallHandler(launcher, (call) async {
      if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
      return true;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(launcher, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BrokerSetupHelp(guide: guide)))));
  }

  for (final guide in [BrokerSetupGuide.zerodha, BrokerSetupGuide.upstox, BrokerSetupGuide.groww]) {
    testWidgets('${guide.title}: lists steps and links', (tester) async {
      await pump(tester, guide);
      expect(find.text('How to get your ${guide.title} API keys'), findsOneWidget);
      for (final (i, step) in guide.steps.indexed) {
        expect(find.text('${i + 1}.'), findsOneWidget);
        expect(find.text(step), findsOneWidget);
      }
      for (final link in guide.links) {
        expect(find.text(link.label), findsOneWidget);
        expect(find.text(link.url), findsOneWidget);
      }
      expect(find.byTooltip('Copy link'), findsNWidgets(guide.links.length));
    });
  }

  testWidgets('tapping a link opens it externally', (tester) async {
    await pump(tester, BrokerSetupGuide.zerodha);
    for (final link in BrokerSetupGuide.zerodha.links) {
      await tester.tap(find.text(link.label));
      await tester.pump();
    }
    expect(launched, BrokerSetupGuide.zerodha.links.map((l) => l.url));
    expect(copied, isEmpty);
  });

  testWidgets('copy link copies the URL and confirms', (tester) async {
    await pump(tester, BrokerSetupGuide.upstox);
    await tester.tap(find.byTooltip('Copy link').last);
    await tester.pump();
    expect(copied, [BrokerSetupGuide.upstox.links.last.url]);
    expect(launched, isEmpty);
    expect(find.text('Link copied'), findsOneWidget);
  });
}
