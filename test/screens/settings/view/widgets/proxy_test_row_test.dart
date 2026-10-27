import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/proxy_health.dart';
import 'package:nexora_app/screens/settings/model/settings_state.dart';
import 'package:nexora_app/screens/settings/view/widgets/proxy_test_row.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, SettingsState state) async {
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProxyTestRow(state: state, onTest: () => taps.add(1))),
    ));
    return taps;
  }

  OutlinedButton button(WidgetTester tester) =>
      tester.widget<OutlinedButton>(find.ancestor(of: find.text('Test proxy'), matching: find.bySubtype<OutlinedButton>()));

  testWidgets('before a test: only the button, which runs the test', (tester) async {
    final taps = await pump(tester, const SettingsState(isWeb: true));
    expect(find.byIcon(Icons.network_check), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    await tester.tap(find.text('Test proxy'));
    expect(taps, [1]);
  });

  testWidgets('while testing: spinner and disabled button', (tester) async {
    await pump(tester, const SettingsState(isWeb: true, testingProxy: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(button(tester).onPressed, isNull);
  });

  testWidgets('a passed test shows a green tick and the message', (tester) async {
    await pump(tester, const SettingsState(proxyHealth: ProxyHealth(ProxyHealthStatus.connected)));
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(icon.color, Colors.green);
    expect(find.text('Connected. Order placement is blocked on this proxy (safe for paper trading).'), findsOneWidget);
  });

  testWidgets('a failed test shows an error icon in the error colour', (tester) async {
    await pump(tester, const SettingsState(proxyHealth: ProxyHealth(ProxyHealthStatus.unreachable)));
    final context = tester.element(find.byType(ProxyTestRow));
    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, Theme.of(context).colorScheme.error);
    expect(find.textContaining("Couldn't reach the proxy"), findsOneWidget);
  });
}
