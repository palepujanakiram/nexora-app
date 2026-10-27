import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/account_edit/usecase/delete_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/save_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/view/account_edit_view.dart';

import '../../fakes.dart';

void main() {
  late FakeAccountRepository accounts;

  setUp(() {
    accounts = FakeAccountRepository();
    sl
      ..reset()
      ..registerFactory(() => SaveAccountUseCase(accounts))
      ..registerFactory(() => DeleteAccountUseCase(accounts));
  });

  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AccountEditView()));
  }

  testWidgets('radio selection switches fields and setup help', (tester) async {
    await pumpView(tester);

    expect(find.byType(RadioListTile<BrokerType>), findsNWidgets(BrokerType.values.length));
    expect(find.text('Redirect URI'), findsNothing);
    expect(find.text('How to get your Zerodha API keys'), findsOneWidget);
    expect(find.text('https://developers.kite.trade/'), findsOneWidget);

    await tester.tap(find.text('Upstox'));
    await tester.pumpAndSettle();

    expect(find.text('Redirect URI'), findsOneWidget);
    expect(find.text('API key (client_id)'), findsOneWidget);
    expect(find.text('How to get your Upstox API keys'), findsOneWidget);
    expect(find.text('https://account.upstox.com/developer/apps'), findsOneWidget);
  });

  testWidgets('switching broker keeps each field\'s own value', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Upstox'));
    await tester.pumpAndSettle();

    String textOf(String label) => tester
        .widget<EditableText>(find.descendant(
            of: find.widgetWithText(TextFormField, label), matching: find.byType(EditableText)))
        .controller
        .text;
    expect(textOf('Redirect URI'), '');
    expect(textOf('Lots per signal'), '1');

    await tester.enterText(find.widgetWithText(TextFormField, 'Redirect URI'), 'https://127.0.0.1/');
    await tester.tap(find.text('Zerodha'));
    await tester.pumpAndSettle();
    expect(textOf('Lots per signal'), '1');
  });

  testWidgets('saving an Upstox account stores the redirect URI', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Upstox'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Mine');
    await tester.enterText(find.widgetWithText(TextFormField, 'API key (client_id)'), 'key');
    await tester.enterText(find.widgetWithText(TextFormField, 'API secret'), 'secret');
    await tester.enterText(find.widgetWithText(TextFormField, 'Redirect URI'), 'https://127.0.0.1/');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = accounts.current.single;
    expect(saved.broker, BrokerType.upstox);
    expect(saved.redirectUri, 'https://127.0.0.1/');
  });
}
