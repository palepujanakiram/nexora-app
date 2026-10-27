import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/common/presentation/widgets/account_badges.dart';
import 'package:nexora_app/screens/accounts/view/widgets/account_tile.dart';

import '../../../../fakes.dart';

void main() {
  late int taps;
  late int logins;
  late List<bool> toggles;

  setUp(() {
    taps = 0;
    logins = 0;
    toggles = [];
  });

  Future<void> pump(WidgetTester tester, BrokerAccount account) => tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AccountTile(
            account: account,
            onTap: () => taps++,
            onEnabledChanged: toggles.add,
            onLogin: () => logins++,
          ),
        ),
      ));

  testWidgets('shows label, masked key, lots, product and badges', (tester) async {
    final account = testAccount().copyWith(apiKey: 'abcdefghij', lots: 3, product: ProductType.intraday);
    await pump(tester, account);

    expect(find.text('Test a'), findsOneWidget);
    expect(find.text('Key abcd••••ij · 3 lot(s) · Intraday (MIS)'), findsOneWidget);
    expect(find.byType(AccountBadges), findsOneWidget);
    expect(find.text('Use by default'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('logged-in account offers Re-login; callbacks fire', (tester) async {
    await pump(tester, testAccount(enabled: true, loggedIn: true));

    expect(find.text('Re-login'), findsOneWidget);
    await tester.tap(find.text('Re-login'));
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Test a'));
    await tester.pump();

    expect(logins, 1);
    expect(toggles, [false]);
    expect(taps, 1);
  });

  testWidgets('logged-out disabled account offers Login', (tester) async {
    await pump(tester, testAccount(enabled: false, loggedIn: false));

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Re-login'), findsNothing);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byType(Switch));
    expect(toggles, [true]);
  });
}
