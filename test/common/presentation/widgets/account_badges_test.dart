import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/presentation/widgets/account_badges.dart';

import '../../../fakes.dart';

void main() {
  Future<ColorScheme> pump(WidgetTester tester, BrokerAccount account) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AccountBadges(account: account))));
    return Theme.of(tester.element(find.byType(AccountBadges))).colorScheme;
  }

  Color pillColor(WidgetTester tester, String text) {
    final container = tester.widget<Container>(find.ancestor(of: find.text(text), matching: find.byType(Container)));
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets('paper account that is logged in', (tester) async {
    final scheme = await pump(tester, testAccount(paper: true, loggedIn: true));

    expect(find.text('PAPER'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('Logged in'), findsOneWidget);
    expect(find.text('Logged out'), findsNothing);
    expect(pillColor(tester, 'PAPER'), scheme.secondaryContainer);
    expect(pillColor(tester, 'Logged in'), Colors.green.withValues(alpha: 0.2));
  });

  testWidgets('live account that is logged out', (tester) async {
    final scheme = await pump(tester, testAccount(paper: false, loggedIn: false));

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('PAPER'), findsNothing);
    expect(find.text('Logged out'), findsOneWidget);
    expect(find.text('Logged in'), findsNothing);
    expect(pillColor(tester, 'LIVE'), scheme.errorContainer);
    expect(pillColor(tester, 'Logged out'), scheme.surfaceContainerHighest);
  });

  testWidgets('an expired token shows as logged out', (tester) async {
    final stale = testAccount().copyWith(tokenIssuedAt: DateTime.now().subtract(const Duration(days: 2)));
    await pump(tester, stale);

    expect(find.text('Logged out'), findsOneWidget);
  });
}
