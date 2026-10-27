import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_app/common/di/injector.dart';
import 'package:nexora_app/common/domain/entities/broker_account.dart';
import 'package:nexora_app/screens/account_edit/usecase/delete_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/usecase/save_account_usecase.dart';
import 'package:nexora_app/screens/account_edit/view/account_edit_view.dart';

import '../../../fakes.dart';

void main() {
  late FakeAccountRepository accounts;

  setUp(() async {
    accounts = FakeAccountRepository([testAccount(), testAccount(id: 'b')]);
    await sl.reset();
    sl
      ..registerFactory(() => SaveAccountUseCase(accounts))
      ..registerFactory(() => DeleteAccountUseCase(accounts));
  });

  /// Opens the editor from a launcher page so popping it can be observed.
  Future<void> open(WidgetTester tester, [BrokerAccount? account]) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.push(ctx, MaterialPageRoute<void>(builder: (_) => AccountEditView(account: account))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  EditableText editable(WidgetTester tester, String label) =>
      tester.widget<EditableText>(find.descendant(of: field(label), matching: find.byType(EditableText)));

  testWidgets('new account has no delete action and defaults to paper mode', (tester) async {
    await open(tester);
    expect(find.text('Add account'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(find.text('Orders are simulated — nothing is sent to the broker.'), findsOneWidget);
  });

  testWidgets('editing prefills the form and saves changes in place', (tester) async {
    await open(tester, accounts.current.first);
    expect(find.text('Edit account'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(editable(tester, 'Name').controller.text, 'Test a');
    expect(editable(tester, 'API key').controller.text, 'k');
    expect(editable(tester, 'API secret').controller.text, 's');
    expect(editable(tester, 'Lots per signal').controller.text, '2');
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    expect(find.text('LIVE: orders will be placed with real money.'), findsOneWidget);

    await tester.enterText(field('Name'), 'Renamed');
    await tester.enterText(field('Lots per signal'), '5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget, reason: 'editor closes after saving');
    expect(accounts.current, hasLength(2));
    final saved = accounts.current.firstWhere((a) => a.id == 'a');
    expect(saved.label, 'Renamed');
    expect(saved.lots, 5);
    expect(saved.accessToken, 't', reason: 'same key and broker keep the session');
  });

  testWidgets('empty or invalid fields show errors and nothing is saved', (tester) async {
    await open(tester);
    await tester.enterText(field('Lots per signal'), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNWidgets(3));
    expect(find.text('Enter a whole number ≥ 1'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget, reason: 'editor stays open');
    expect(accounts.current, hasLength(2));

    await tester.tap(find.text('Upstox'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(4), reason: 'redirect URI is required for Upstox');
  });

  testWidgets('secret is hidden until the eye button is tapped', (tester) async {
    await open(tester);
    expect(editable(tester, 'API secret').obscureText, isTrue);
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(editable(tester, 'API secret').obscureText, isFalse);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(editable(tester, 'API secret').obscureText, isTrue);
  });

  testWidgets('product dropdown and paper switch are saved', (tester) async {
    await open(tester);
    await tester.enterText(field('Name'), 'Mine');
    await tester.enterText(field('API key'), 'key');
    await tester.enterText(field('API secret'), 'secret');

    expect(find.text(ProductType.carryForward.label), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<ProductType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProductType.intraday.label).last);
    await tester.pumpAndSettle();
    expect(find.text(ProductType.intraday.label), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(find.text('LIVE: orders will be placed with real money.'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = accounts.current.firstWhere((a) => a.label == 'Mine');
    expect(saved.product, ProductType.intraday);
    expect(saved.paperMode, isFalse);
    expect(saved.enabled, isTrue);
    expect(saved.lots, 1);
  });

  testWidgets('delete asks first; cancel keeps the account', (tester) async {
    await open(tester, accounts.current.first);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.text('Remove "Test a" and its stored keys from this device?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsNothing);
    expect(find.text('Edit account'), findsOneWidget);
    expect(accounts.current, hasLength(2));

    // Dismissing the dialog also keeps it.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Edit account'), findsOneWidget);
    expect(accounts.current, hasLength(2));
  });

  testWidgets('confirming delete removes the account and closes the editor', (tester) async {
    await open(tester, accounts.current.first);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(accounts.current.map((a) => a.id), ['b']);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Edit account'), findsNothing);
  });

  testWidgets('a server account keeps its stored secret when the field is left empty', (tester) async {
    final serverAccount = testAccount(id: 's').copyWith(apiKey: 'upke••••34', apiSecret: '');
    accounts = FakeAccountRepository([serverAccount]);
    await open(tester, serverAccount);
    expect(find.text('Saved on the server. Leave empty to keep it.'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNothing);
    expect(accounts.current.single.apiSecret, '', reason: 'empty means "keep" to the server');
    expect(accounts.current.single.apiKey, 'upke••••34');
  });
}
